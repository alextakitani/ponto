# Página "conta suspensa" (Q34): o único destino que o user suspenso consegue
# abrir. Isenta do gate de suspensão (senão o redirect entraria em loop); ainda
# exige estar autenticado (o gate roda depois do require_authentication).
class SuspensionsController < ApplicationController
  allow_suspended_access

  def show
  end
end
