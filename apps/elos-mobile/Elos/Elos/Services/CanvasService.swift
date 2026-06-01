import Foundation
import SwiftData

// MARK: - Canvas API Response Types

private struct CanvasCourse: Decodable {
    let id: Int
    let name: String
    let workflow_state: String?
}

private struct CanvasCalendarEvent: Decodable {
    let id: Int
    let title: String?
    let start_at: String?
    let end_at: String?
}

private struct CanvasAssignment: Decodable {
    let id: Int
    let name: String
    let due_at: String?
    let submission_types: [String]?
}

private struct CanvasUpcomingEvent: Decodable {
    let id: Int
    let title: String
    let start_at: String?
    let type: String?
    let assignment: AssignmentRef?

    struct AssignmentRef: Decodable {
        let submission_types: [String]?
    }
}

// MARK: - CanvasService

struct CanvasService {
    static let shared = CanvasService()
    private init() {}

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }()

    private static func dayString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    private static func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }

    func sync(baseURL: String, token: String, ownerID: String, context: ModelContext) async throws {
        let base = "https://\(baseURL)/api/v1"
        let headers = ["Authorization": "Bearer \(token)"]
        let now = Date()
        let cal = Calendar.current

        // 1. Sync courses
        let courses: [CanvasCourse] = try await fetch(
            url: "\(base)/courses?enrollment_type=student&per_page=50&enrollment_state=active",
            headers: headers
        )
        for course in courses where course.workflow_state == "available" || course.workflow_state == nil {
            let courseIDStr = "\(course.id)"
            let desc = FetchDescriptor<CourseRecord>(predicate: #Predicate<CourseRecord> {
                $0.courseID == courseIDStr && $0.ownerID == ownerID
            })
            if (try? context.fetch(desc).first) == nil {
                context.insert(CourseRecord(ownerID: ownerID, courseID: courseIDStr, name: course.name, difficulty: 1))
            }
        }
        try? context.save()

        // 2. Calendar events (class periods) for next 60 days
        let endDate = cal.date(byAdding: .day, value: 60, to: now) ?? now
        let startStr = Self.dayString(now)
        let endStr   = Self.dayString(endDate)
        let calURL   = "\(base)/calendar_events?type=event&start_date=\(startStr)&end_date=\(endStr)&per_page=100"
        let calEvents: [CanvasCalendarEvent] = (try? await fetch(url: calURL, headers: headers)) ?? []
        for ev in calEvents {
            guard let startAtStr = ev.start_at,
                  let startDate = Self.isoFormatter.date(from: startAtStr) else { continue }
            let dateStr = Self.dayString(startDate)
            let timeStr = Self.timeString(startDate)
            let title   = ev.title ?? "Class"
            let srcID   = "canvas_event_\(ev.id)"
            let dur: Int = {
                guard let endAtStr = ev.end_at,
                      let endDate = Self.isoFormatter.date(from: endAtStr) else { return 55 }
                return Int(endDate.timeIntervalSince(startDate) / 60)
            }()
            let desc = FetchDescriptor<ScheduleEventRecord>(predicate: #Predicate<ScheduleEventRecord> {
                $0.sourceID == srcID && $0.ownerID == ownerID
            })
            if let existing = try? context.fetch(desc).first {
                existing.title = title; existing.startTime = timeStr
                existing.date = dateStr; existing.durationMinutes = dur
            } else {
                context.insert(ScheduleEventRecord(
                    ownerID: ownerID, date: dateStr, startTime: timeStr,
                    title: title, moduleType: "class", durationMinutes: dur, sourceID: srcID
                ))
            }
        }
        try? context.save()

        // 3. Upcoming events (quizzes/exams)
        let upcomingURL = "\(base)/users/self/upcoming_events"
        let upcoming: [CanvasUpcomingEvent] = (try? await fetch(url: upcomingURL, headers: headers)) ?? []
        for ev in upcoming {
            guard let startAtStr = ev.start_at,
                  let startDate = Self.isoFormatter.date(from: startAtStr) else { continue }
            let isQuiz = ev.type == "quiz" ||
                ev.assignment?.submission_types?.contains("online_quiz") == true
            guard isQuiz else { continue }
            let dateStr   = Self.dayString(startDate)
            let srcID     = "canvas_upcoming_\(ev.id)"
            let daysAway  = cal.dateComponents([.day],
                from: cal.startOfDay(for: now),
                to:   cal.startOfDay(for: startDate)
            ).day ?? 0
            let examDesc = FetchDescriptor<ExamRecord>(predicate: #Predicate<ExamRecord> {
                $0.sourceID == srcID && $0.ownerID == ownerID
            })
            if let existing = try? context.fetch(examDesc).first {
                existing.title = ev.title; existing.dateString = dateStr; existing.daysAway = daysAway
            } else {
                context.insert(ExamRecord(
                    ownerID: ownerID, subject: "", title: ev.title,
                    dateString: dateStr, daysAway: daysAway, sourceID: srcID
                ))
            }
        }
        try? context.save()

        // 4. Assignments for each course
        for course in courses {
            let aURL = "\(base)/courses/\(course.id)/assignments?bucket=upcoming&per_page=30"
            let assigns: [CanvasAssignment] = (try? await fetch(url: aURL, headers: headers)) ?? []
            for a in assigns {
                guard let dueStr = a.due_at,
                      let dueDate = Self.isoFormatter.date(from: dueStr) else { continue }
                let dateStr    = Self.dayString(dueDate)
                let srcID      = "canvas_assign_\(a.id)"
                let daysUntil  = cal.dateComponents([.day],
                    from: cal.startOfDay(for: now),
                    to:   cal.startOfDay(for: dueDate)
                ).day ?? 999
                let aDesc = FetchDescriptor<AssignmentRecord>(predicate: #Predicate<AssignmentRecord> {
                    $0.sourceID == srcID && $0.ownerID == ownerID
                })
                if let existing = try? context.fetch(aDesc).first {
                    existing.name = a.name; existing.dueString = dateStr; existing.subject = course.name
                } else {
                    context.insert(AssignmentRecord(
                        ownerID: ownerID, name: a.name, subject: course.name,
                        dueString: dateStr, isUrgent: daysUntil <= 3, isDone: false, sourceID: srcID
                    ))
                }
            }
        }
        try? context.save()
    }

    // MARK: - HTTP helper

    private func fetch<T: Decodable>(url: String, headers: [String: String]) async throws -> T {
        guard let reqURL = URL(string: url) else { throw URLError(.badURL) }
        var req = URLRequest(url: reqURL)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
