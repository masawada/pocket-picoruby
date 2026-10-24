# Japanese text: draw_text takes UTF-8, ASCII is 8 px wide and
# JIS X 0208 characters (kana, kanji, full-width symbols) are 16 px wide.

D = Pocket::Display
WHITE = 0xffff
GREY = Pocket.rgb(150, 150, 170)
BG = Pocket.rgb(20, 16, 40)

D.clear(BG)
D.draw_text(8, 8, "Pocket で PicoRuby", WHITE)
D.draw_text(8, 32, "日本語フォント: 東雲 16x16", WHITE)
D.draw_text(8, 56, "ひらがな カタカナ 漢字 ＡＢＣ", WHITE)
D.draw_text(8, 80, "テトリスは Ruby で書いた。", GREY, BG)
D.draw_text(8, 104, "1フレーム = 約3000命令", GREY)
D.draw_text(8, 136, "☆ 記号も出る ☆ → ※", WHITE)
D.draw_text(8, 168, "収録外の文字は ? になる: 🎮", GREY)
D.flush

loop { Pocket.wait_vsync }
