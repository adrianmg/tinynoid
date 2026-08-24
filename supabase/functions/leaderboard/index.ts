Deno.serve(() => new Response(
  JSON.stringify({ error: "Use the leaderboard RPCs directly." }),
  {
    status: 410,
    headers: { "Content-Type": "application/json" },
  },
));
