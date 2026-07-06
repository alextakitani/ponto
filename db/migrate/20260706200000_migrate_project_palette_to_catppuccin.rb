# Migração de dados (Q52): remapeia a paleta antiga (tons ~Tailwind 500/600) para os
# 12 acentos do Catppuccin Latte, posição a posição (old→new). Necessário porque a
# validação `color` no Project exige inclusão na PALETTE; projetos com cores antigas
# falhariam em qualquer update após a troca da constante.
#
# Mapeamento 1:1 por posição (índice original → Catppuccin Latte):
#   0  #e05252 → #d20f39  red
#   1  #e07a3c → #fe640b  peach
#   2  #d9a520 → #df8e1d  yellow
#   3  #4c9a4c → #40a02b  green
#   4  #2f9e8f → #179299  teal
#   5  #2f7fd1 → #1e66f5  blue
#   6  #4f5ed9 → #7287fd  lavender
#   7  #7b52c9 → #8839ef  mauve
#   8  #c0479e → #ea76cb  pink
#   9  #8a6d3b → #e64553  maroon
#  10  #5b7083 → #209fb5  sapphire
#  11  #b0863c → #dd7878  flamingo
class MigrateProjectPaletteToCatppuccin < ActiveRecord::Migration[8.1]
  # Mapeamento antigo → novo, por posição.
  COLOR_MAP = {
    "#e05252" => "#d20f39",
    "#e07a3c" => "#fe640b",
    "#d9a520" => "#df8e1d",
    "#4c9a4c" => "#40a02b",
    "#2f9e8f" => "#179299",
    "#2f7fd1" => "#1e66f5",
    "#4f5ed9" => "#7287fd",
    "#7b52c9" => "#8839ef",
    "#c0479e" => "#ea76cb",
    "#8a6d3b" => "#e64553",
    "#5b7083" => "#209fb5",
    "#b0863c" => "#dd7878"
  }.freeze

  def up
    COLOR_MAP.each do |old_color, new_color|
      Project.where(color: old_color).update_all(color: new_color)
    end
  end

  def down
    COLOR_MAP.each do |old_color, new_color|
      Project.where(color: new_color).update_all(color: old_color)
    end
  end
end
