class_name ScoreShare
extends RefCounted

const GAME_URL := "https://adrianmg.github.io/tinynoid/"


static func share(
	player_name: String,
	score: int,
	outcome: String,
	png_data: PackedByteArray
) -> bool:
	var text := "%s scored %d points in TINYNOID!" % [
		player_name,
		score,
	]
	if outcome == "campaign_clear":
		text = "%s cleared TINYNOID with %d points!" % [
			player_name,
			score,
		]

	if OS.has_feature("web"):
		return _share_on_web(text, png_data)
	return OS.shell_open(_x_intent_url(text)) == OK


static func _share_on_web(
	text: String,
	png_data: PackedByteArray
) -> bool:
	var script := """
(() => {
  const text = %s;
  const gameUrl = %s;
  const fallbackUrl =
    "https://x.com/intent/post?text=" + encodeURIComponent(text)
    + "&url=" + encodeURIComponent(gameUrl);
  const fallback = () => (
    window.open(fallbackUrl, "_blank", "noopener,noreferrer") !== null
  );
  try {
    const raw = atob(%s);
    const bytes = Uint8Array.from(raw, (character) => character.charCodeAt(0));
    const file = new File([bytes], "tinynoid-score.png", { type: "image/png" });
    const shareData = {
      title: "TINYNOID SCORE",
      text,
      url: gameUrl,
      files: [file],
    };
    if (
      navigator.share
      && navigator.canShare
      && navigator.canShare(shareData)
    ) {
      navigator.share(shareData).catch(() => {});
      return true;
    }
    return fallback();
  } catch (_error) {
    return fallback();
  }
})();
""" % [
		JSON.stringify(text),
		JSON.stringify(GAME_URL),
		JSON.stringify(Marshalls.raw_to_base64(png_data)),
	]
	return bool(JavaScriptBridge.eval(script, true))


static func _x_intent_url(text: String) -> String:
	return "https://x.com/intent/post?text=%s&url=%s" % [
		text.uri_encode(),
		GAME_URL.uri_encode(),
	]
