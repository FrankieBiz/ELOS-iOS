export function parseMoodAndBrief(raw: string): { briefText: string; mood: string } {
  const moodMatch = raw.match(/MOOD:\s*(positive|cautious|alert)/i);
  const mood = moodMatch ? moodMatch[1].toLowerCase() : "cautious";
  const briefText = raw.replace(/\n?MOOD:\s*(positive|cautious|alert)\s*$/i, "").trim();
  return { briefText, mood };
}

export async function callDeepSeek(prompt: string): Promise<string> {
  const res = await fetch("https://api.deepseek.com/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.DEEPSEEK_API_KEY}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: [{ role: "user", content: prompt }],
      max_tokens: 150,
      temperature: 0.5,
    }),
  });
  if (!res.ok) throw new Error(`DeepSeek API error: ${res.status}`);
  const data = await res.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error("DeepSeek returned no choices");
  return content as string;
}
