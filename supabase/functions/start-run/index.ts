Deno.serve(() => new Response(
  JSON.stringify({ error: "Run tickets are no longer required." }),
  {
    status: 410,
    headers: { "Content-Type": "application/json" },
  },
));
