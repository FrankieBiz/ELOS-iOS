import Foundation
import SwiftData

@Model
final class HabitRecord {
    var id: String
    var ownerID: String
    var label: String
    var category: String
    var streak: Int
    var isDone: Bool
    var lastResetDate: Date

    init(id: String, ownerID: String, label: String, category: String,
         streak: Int = 0, isDone: Bool = false, lastResetDate: Date = Date()) {
        self.id            = id
        self.ownerID       = ownerID
        self.label         = label
        self.category      = category
        self.streak        = streak
        self.isDone        = isDone
        self.lastResetDate = lastResetDate
    }
}

@Model
final class MealEntryRecord {
    var id: String
    var ownerID: String
    var mealKey: String
    var logDate: Date
    var name: String
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int

    init(id: String = UUID().uuidString, ownerID: String, mealKey: String,
         logDate: Date = Date(), name: String, kcal: Int, protein: Int, carbs: Int, fat: Int) {
        self.id      = id
        self.ownerID = ownerID
        self.mealKey = mealKey
        self.logDate = logDate
        self.name    = name
        self.kcal    = kcal
        self.protein = protein
        self.carbs   = carbs
        self.fat     = fat
    }
}

@Model
final class SleepRecord {
    var id: String
    var ownerID: String
    var logDate: Date
    var bedString: String
    var wakeString: String
    var duration: Double
    var quality: Int

    init(id: String = UUID().uuidString, ownerID: String, logDate: Date = Date(),
         bedString: String, wakeString: String, duration: Double, quality: Int) {
        self.id         = id
        self.ownerID    = ownerID
        self.logDate    = logDate
        self.bedString  = bedString
        self.wakeString = wakeString
        self.duration   = duration
        self.quality    = quality
    }
}

@Model
final class HydrationRecord {
    var id: String
    var ownerID: String
    var logDate: Date
    var ouncesConsumed: Int

    init(id: String = UUID().uuidString, ownerID: String,
         logDate: Date = Date(), ouncesConsumed: Int) {
        self.id             = id
        self.ownerID        = ownerID
        self.logDate        = logDate
        self.ouncesConsumed = ouncesConsumed
    }
}

@Model
final class AssignmentRecord {
    var id: String
    var ownerID: String
    var name: String
    var subject: String
    var dueString: String
    var isUrgent: Bool
    var isDone: Bool
    var sourceID: String   // Canvas assignment ID or ""

    init(id: String = UUID().uuidString, ownerID: String, name: String,
         subject: String, dueString: String, isUrgent: Bool, isDone: Bool,
         sourceID: String = "") {
        self.id        = id
        self.ownerID   = ownerID
        self.name      = name
        self.subject   = subject
        self.dueString = dueString
        self.isUrgent  = isUrgent
        self.isDone    = isDone
        self.sourceID  = sourceID
    }
}

@Model
final class ExamRecord {
    var id: String
    var ownerID: String
    var subject: String
    var title: String
    var dateString: String
    var daysAway: Int
    var sourceID: String   // Canvas event ID or ""

    init(id: String = UUID().uuidString, ownerID: String, subject: String,
         title: String, dateString: String, daysAway: Int, sourceID: String = "") {
        self.id         = id
        self.ownerID    = ownerID
        self.subject    = subject
        self.title      = title
        self.dateString = dateString
        self.daysAway   = daysAway
        self.sourceID   = sourceID
    }
}

@Model
final class WorkoutSessionRecord {
    var id: String
    var ownerID: String
    var startedAt: Date
    var finishedAt: Date?
    var sessionRPE: Int
    var notes: String
    var templateID: String
    var totalVolume: Double

    init(id: String = UUID().uuidString, ownerID: String,
         startedAt: Date = Date(), finishedAt: Date? = nil,
         sessionRPE: Int = 0, notes: String = "",
         templateID: String = "", totalVolume: Double = 0) {
        self.id          = id
        self.ownerID     = ownerID
        self.startedAt   = startedAt
        self.finishedAt  = finishedAt
        self.sessionRPE  = sessionRPE
        self.notes       = notes
        self.templateID  = templateID
        self.totalVolume = totalVolume
    }
}

@Model
final class ExerciseSetRecord {
    var id: String
    var ownerID: String
    var sessionID: String
    var exerciseName: String
    var setIndex: Int
    var weightKg: Double
    var reps: Int
    var rpe: Double
    var rir: Int
    var isDone: Bool
    var completedAt: Date?
    var equipmentId: String?
    var equipmentDedupeKey: String?
    var equipmentBrandName: String?

    init(id: String = UUID().uuidString, ownerID: String,
         sessionID: String, exerciseName: String, setIndex: Int,
         weightKg: Double = 0, reps: Int = 0,
         rpe: Double = 0, rir: Int = -1,
         isDone: Bool = false, completedAt: Date? = nil,
         equipmentId: String? = nil, equipmentDedupeKey: String? = nil,
         equipmentBrandName: String? = nil) {
        self.id                  = id
        self.ownerID             = ownerID
        self.sessionID           = sessionID
        self.exerciseName        = exerciseName
        self.setIndex            = setIndex
        self.weightKg            = weightKg
        self.reps                = reps
        self.rpe                 = rpe
        self.rir                 = rir
        self.isDone              = isDone
        self.completedAt         = completedAt
        self.equipmentId         = equipmentId
        self.equipmentDedupeKey  = equipmentDedupeKey
        self.equipmentBrandName  = equipmentBrandName
    }
}

@Model
final class ExerciseDefinitionRecord {
    var id: String
    var ownerID: String
    var name: String
    var primaryMuscle: String
    var secondaryMusclesJSON: String
    var equipment: String
    var movementPattern: String
    var isCustom: Bool

    init(id: String = UUID().uuidString, ownerID: String = "",
         name: String, primaryMuscle: String,
         secondaryMusclesJSON: String = "[]",
         equipment: String = "", movementPattern: String = "",
         isCustom: Bool = false) {
        self.id                   = id
        self.ownerID              = ownerID
        self.name                 = name
        self.primaryMuscle        = primaryMuscle
        self.secondaryMusclesJSON = secondaryMusclesJSON
        self.equipment            = equipment
        self.movementPattern      = movementPattern
        self.isCustom             = isCustom
    }

    var secondaryMuscles: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(secondaryMusclesJSON.utf8))) ?? []
    }
}

@Model
final class WorkoutTemplateRecord {
    var id: String
    var ownerID: String
    var name: String
    var createdAt: Date
    var serverConfirmed: Bool

    init(id: String = UUID().uuidString, ownerID: String,
         name: String, createdAt: Date = Date(), serverConfirmed: Bool = false) {
        self.id              = id
        self.ownerID         = ownerID
        self.name            = name
        self.createdAt       = createdAt
        self.serverConfirmed = serverConfirmed
    }
}

@Model
final class TemplateExerciseRecord {
    var id: String
    var ownerID: String
    var templateID: String
    var exerciseID: String?
    var exerciseName: String
    var orderIndex: Int
    var targetSets: Int
    var targetReps: String
    var targetRPE: Double
    var restSeconds: Int
    var notes: String
    var equipmentId: String?
    var equipmentDedupeKey: String?
    var equipmentBrandName: String?

    init(id: String = UUID().uuidString, ownerID: String,
         templateID: String, exerciseID: String? = nil,
         exerciseName: String, orderIndex: Int,
         targetSets: Int = 3, targetReps: String = "8-10",
         targetRPE: Double = 0, restSeconds: Int = 90,
         notes: String = "",
         equipmentId: String? = nil, equipmentDedupeKey: String? = nil,
         equipmentBrandName: String? = nil) {
        self.id                  = id
        self.ownerID             = ownerID
        self.templateID          = templateID
        self.exerciseID          = exerciseID
        self.exerciseName        = exerciseName
        self.orderIndex          = orderIndex
        self.targetSets          = targetSets
        self.targetReps          = targetReps
        self.targetRPE           = targetRPE
        self.restSeconds         = restSeconds
        self.notes               = notes
        self.equipmentId         = equipmentId
        self.equipmentDedupeKey  = equipmentDedupeKey
        self.equipmentBrandName  = equipmentBrandName
    }
}

@Model
final class ReadinessCheckInRecord {
    var id: String
    var ownerID: String
    var logDate: String
    var sleepQuality: Int
    var soreness: Int
    var stress: Int
    var motivation: Int
    var overallScore: Double

    init(id: String = UUID().uuidString, ownerID: String,
         logDate: String, sleepQuality: Int, soreness: Int,
         stress: Int, motivation: Int) {
        self.id           = id
        self.ownerID      = ownerID
        self.logDate      = logDate
        self.sleepQuality = sleepQuality
        self.soreness     = soreness
        self.stress       = stress
        self.motivation   = motivation
        self.overallScore = Double(sleepQuality + soreness + stress + motivation) / 4.0
    }
}

@Model
final class CreatorRecord {
    var id: String
    var name: String
    var slug: String
    var bio: String
    var category: String
    var trainingStyle: String
    var goalsJSON: String
    var splitTypesJSON: String
    var difficulty: String
    var imageURL: String
    var isVerified: Bool

    init(id: String, name: String, slug: String, bio: String = "",
         category: String, trainingStyle: String = "",
         goalsJSON: String = "[]", splitTypesJSON: String = "[]",
         difficulty: String = "intermediate", imageURL: String = "", isVerified: Bool = false) {
        self.id            = id
        self.name          = name
        self.slug          = slug
        self.bio           = bio
        self.category      = category
        self.trainingStyle = trainingStyle
        self.goalsJSON     = goalsJSON
        self.splitTypesJSON = splitTypesJSON
        self.difficulty    = difficulty
        self.imageURL      = imageURL
        self.isVerified    = isVerified
    }

    var goals: [String] { (try? JSONDecoder().decode([String].self, from: Data(goalsJSON.utf8))) ?? [] }
    var splitTypes: [String] { (try? JSONDecoder().decode([String].self, from: Data(splitTypesJSON.utf8))) ?? [] }
}

@Model
final class LibraryWorkoutRecord {
    var id: String
    var creatorID: String
    var creatorName: String
    var creatorSlug: String
    var title: String
    var programType: String
    var daysPerWeek: Int
    var goal: String
    var difficulty: String
    var durationWeeks: Int
    var estSessionMins: Int
    var equipmentJSON: String
    var muscleGroupsJSON: String
    var tagsJSON: String
    var sourceURL: String
    var disclaimer: String
    var isSaved: Bool

    init(id: String, creatorID: String, creatorName: String = "", creatorSlug: String = "",
         title: String, programType: String = "", daysPerWeek: Int = 0,
         goal: String = "", difficulty: String = "intermediate",
         durationWeeks: Int = 0, estSessionMins: Int = 0,
         equipmentJSON: String = "[]", muscleGroupsJSON: String = "[]", tagsJSON: String = "[]",
         sourceURL: String = "", disclaimer: String = "", isSaved: Bool = false) {
        self.id             = id
        self.creatorID      = creatorID
        self.creatorName    = creatorName
        self.creatorSlug    = creatorSlug
        self.title          = title
        self.programType    = programType
        self.daysPerWeek    = daysPerWeek
        self.goal           = goal
        self.difficulty     = difficulty
        self.durationWeeks  = durationWeeks
        self.estSessionMins = estSessionMins
        self.equipmentJSON  = equipmentJSON
        self.muscleGroupsJSON = muscleGroupsJSON
        self.tagsJSON       = tagsJSON
        self.sourceURL      = sourceURL
        self.disclaimer     = disclaimer
        self.isSaved        = isSaved
    }

    var equipment: [String] { (try? JSONDecoder().decode([String].self, from: Data(equipmentJSON.utf8))) ?? [] }
    var muscleGroups: [String] { (try? JSONDecoder().decode([String].self, from: Data(muscleGroupsJSON.utf8))) ?? [] }
    var tags: [String] { (try? JSONDecoder().decode([String].self, from: Data(tagsJSON.utf8))) ?? [] }
}

@Model
final class MachineRecord {
    var id: String
    var name: String
    var slug: String
    var category: String
    var equipmentType: String
    var primaryMusclesJSON: String
    var secondaryMusclesJSON: String
    var descriptionText: String
    var imageURL: String
    var tagsJSON: String

    init(id: String, name: String, slug: String,
         category: String, equipmentType: String,
         primaryMusclesJSON: String = "[]", secondaryMusclesJSON: String = "[]",
         descriptionText: String = "", imageURL: String = "", tagsJSON: String = "[]") {
        self.id                  = id
        self.name                = name
        self.slug                = slug
        self.category            = category
        self.equipmentType       = equipmentType
        self.primaryMusclesJSON  = primaryMusclesJSON
        self.secondaryMusclesJSON = secondaryMusclesJSON
        self.descriptionText     = descriptionText
        self.imageURL            = imageURL
        self.tagsJSON            = tagsJSON
    }

    var primaryMuscles: [String] { (try? JSONDecoder().decode([String].self, from: Data(primaryMusclesJSON.utf8))) ?? [] }
    var secondaryMuscles: [String] { (try? JSONDecoder().decode([String].self, from: Data(secondaryMusclesJSON.utf8))) ?? [] }
    var tags: [String] { (try? JSONDecoder().decode([String].self, from: Data(tagsJSON.utf8))) ?? [] }
}

@Model
final class UserSplitRecord {
    var id: String
    var ownerID: String
    var name: String
    var createdAt: Date
    var isActive: Bool
    var activatedAt: Date?
    var skippedDatesJSON: String   // JSON array of "yyyy-MM-dd" strings
    var libraryKey: String = ""    // library split ID, "" for custom splits
    var serverID: String = ""      // backend UUID, "" until confirmed by server
    var syncPending: Bool = false  // true until successfully POSTed to backend
    var scheduledStartAt: Date? = nil    // non-nil = pending; activates when Date() >= this
    var pinnedWeekdaysJSON: String? = nil // JSON [Int] of Calendar weekday numbers; nil = ordinal rotation
    var includeWarmups: Bool = false      // true = warmup exercises shown before session

    init(id: String = UUID().uuidString,
         ownerID: String,
         name: String,
         isActive: Bool = false,
         createdAt: Date = Date(),
         activatedAt: Date? = nil,
         skippedDatesJSON: String = "[]",
         libraryKey: String = "",
         serverID: String = "",
         syncPending: Bool = false,
         scheduledStartAt: Date? = nil,
         pinnedWeekdaysJSON: String? = nil,
         includeWarmups: Bool = false) {
        self.id                  = id
        self.ownerID             = ownerID
        self.name                = name
        self.createdAt           = createdAt
        self.isActive            = isActive
        self.activatedAt         = activatedAt
        self.skippedDatesJSON    = skippedDatesJSON
        self.libraryKey          = libraryKey
        self.serverID            = serverID
        self.syncPending         = syncPending
        self.scheduledStartAt    = scheduledStartAt
        self.pinnedWeekdaysJSON  = pinnedWeekdaysJSON
        self.includeWarmups      = includeWarmups
    }

    var skippedDates: Set<String> {
        (try? JSONDecoder().decode([String].self, from: Data(skippedDatesJSON.utf8)))
            .map(Set.init) ?? []
    }

    func addSkip(dateString: String) {
        var arr = (try? JSONDecoder().decode([String].self, from: Data(skippedDatesJSON.utf8))) ?? []
        if !arr.contains(dateString) { arr.append(dateString) }
        skippedDatesJSON = (try? String(data: JSONEncoder().encode(arr), encoding: .utf8)) ?? skippedDatesJSON
    }

    var pinnedWeekdays: [Int]? {
        get {
            guard let json = pinnedWeekdaysJSON else { return nil }
            return try? JSONDecoder().decode([Int].self, from: Data(json.utf8))
        }
        set {
            pinnedWeekdaysJSON = newValue.flatMap {
                try? String(data: JSONEncoder().encode($0), encoding: .utf8)
            }
        }
    }
}

@Model
final class ScheduleEventRecord {
    var id: String
    var ownerID: String
    var date: String          // "yyyy-MM-dd"
    var startTime: String     // "HH:mm" or ""
    var title: String
    var moduleType: String    // "gym" | "exam" | "assignment" | "class" | "meal" | "sleep"
    var durationMinutes: Int
    var isDone: Bool
    var sourceID: String      // Canvas event ID or split day ID

    init(id: String = UUID().uuidString, ownerID: String,
         date: String, startTime: String = "", title: String,
         moduleType: String, durationMinutes: Int = 0,
         isDone: Bool = false, sourceID: String = "") {
        self.id              = id
        self.ownerID         = ownerID
        self.date            = date
        self.startTime       = startTime
        self.title           = title
        self.moduleType      = moduleType
        self.durationMinutes = durationMinutes
        self.isDone          = isDone
        self.sourceID        = sourceID
    }
}

@Model
final class CourseRecord {
    var id: String
    var ownerID: String
    var courseID: String      // Canvas course ID
    var name: String
    var difficulty: Int       // 0 = easy, 1 = normal (push 1 day), 2 = hard (push 2 days)

    init(id: String = UUID().uuidString, ownerID: String,
         courseID: String, name: String, difficulty: Int = 1) {
        self.id         = id
        self.ownerID    = ownerID
        self.courseID   = courseID
        self.name       = name
        self.difficulty = difficulty
    }
}

@Model
final class UserSplitDayRecord {
    var id: String
    var splitID: String
    var orderIndex: Int
    var dayLabel: String
    var dayName: String
    var templateID: String
    var isRest: Bool
    var exercisesJSON: String  // JSON array of {id, name} for directly-assigned exercises

    init(id: String = UUID().uuidString, splitID: String,
         orderIndex: Int, dayLabel: String,
         dayName: String = "", templateID: String = "", isRest: Bool = false,
         exercisesJSON: String = "[]") {
        self.id            = id
        self.splitID       = splitID
        self.orderIndex    = orderIndex
        self.dayLabel      = dayLabel
        self.dayName       = dayName
        self.templateID    = templateID
        self.isRest        = isRest
        self.exercisesJSON = exercisesJSON
    }
}

@Model
final class SavedLibraryWorkoutRecord {
    var id: String
    var ownerID: String
    var workoutID: String
    var savedAt: Date

    init(id: String = UUID().uuidString, ownerID: String, workoutID: String, savedAt: Date = Date()) {
        self.id       = id
        self.ownerID  = ownerID
        self.workoutID = workoutID
        self.savedAt  = savedAt
    }
}

@Model
final class FriendRecord {
    var id: String
    var userID: String
    var username: String
    var firstName: String
    var lastName: String
    var avatarColor: String
    var status: String
    var isRequester: Bool

    init(id: String, userID: String, username: String = "",
         firstName: String = "", lastName: String = "",
         avatarColor: String = "#6C47FF", status: String = "pending",
         isRequester: Bool = false) {
        self.id          = id
        self.userID      = userID
        self.username    = username
        self.firstName   = firstName
        self.lastName    = lastName
        self.avatarColor = avatarColor
        self.status      = status
        self.isRequester = isRequester
    }

    var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (username.isEmpty ? "Unknown" : "@\(username)") : full
    }

    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return (f + l).uppercased().isEmpty ? "?" : (f + l).uppercased()
    }
}

@Model
final class LeaderboardEntryRecord {
    var id: String
    var ownerID: String
    var metric: String
    var weekStart: String
    var rank: Int
    var rankUserID: String
    var rankUsername: String
    var rankFirstName: String
    var rankLastName: String
    var rankAvatarColor: String
    var value: Double
    var isSelf: Bool

    init(id: String, ownerID: String, metric: String, weekStart: String,
         rank: Int, rankUserID: String, rankUsername: String = "",
         rankFirstName: String = "", rankLastName: String = "",
         rankAvatarColor: String = "#6C47FF", value: Double, isSelf: Bool = false) {
        self.id             = id
        self.ownerID        = ownerID
        self.metric         = metric
        self.weekStart      = weekStart
        self.rank           = rank
        self.rankUserID     = rankUserID
        self.rankUsername   = rankUsername
        self.rankFirstName  = rankFirstName
        self.rankLastName   = rankLastName
        self.rankAvatarColor = rankAvatarColor
        self.value          = value
        self.isSelf         = isSelf
    }

    var displayName: String {
        let full = "\(rankFirstName) \(rankLastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (rankUsername.isEmpty ? "Unknown" : "@\(rankUsername)") : full
    }

    var initials: String {
        let f = rankFirstName.first.map(String.init) ?? ""
        let l = rankLastName.first.map(String.init) ?? ""
        return (f + l).uppercased().isEmpty ? "?" : (f + l).uppercased()
    }
}

@Model
final class UserProfileRecord {
    var id: String
    var ownerID: String
    var email: String
    var firstName: String
    var lastName: String
    var heightCm: Double
    var weightKg: Double
    var ageYears: Int
    var trainingExperience: String
    var trainingGoal: String
    var schoolName: String
    var schoolYear: String
    var calGoal: Int
    var proteinGoal: Int
    var carbGoal: Int
    var fatGoal: Int
    var onboardingComplete: Bool

    init(id: String, ownerID: String, email: String,
         firstName: String = "", lastName: String = "",
         heightCm: Double = 0, weightKg: Double = 0, ageYears: Int = 0,
         trainingExperience: String = "beginner", trainingGoal: String = "hypertrophy",
         schoolName: String = "", schoolYear: String = "sophomore",
         calGoal: Int = 2500, proteinGoal: Int = 180, carbGoal: Int = 300, fatGoal: Int = 80,
         onboardingComplete: Bool = false) {
        self.id                 = id
        self.ownerID            = ownerID
        self.email              = email
        self.firstName          = firstName
        self.lastName           = lastName
        self.heightCm           = heightCm
        self.weightKg           = weightKg
        self.ageYears           = ageYears
        self.trainingExperience = trainingExperience
        self.trainingGoal       = trainingGoal
        self.schoolName         = schoolName
        self.schoolYear         = schoolYear
        self.calGoal            = calGoal
        self.proteinGoal        = proteinGoal
        self.carbGoal           = carbGoal
        self.fatGoal            = fatGoal
        self.onboardingComplete = onboardingComplete
    }
}
