# Clientes (Fatia 2.2) — 1ª tabela de domínio. Controller fino sobre o model rico
# (STYLE.md): a policy resolve pode/não-pode e o `authorized_scope` filtra pra bolha
# do user (Q23), então o controller nunca vê dado alheio. Responde HTML (telas no
# shell) e JSON (Q73 — superfície total; escalares, nunca Money cru — Q11).
class ClientsController < ApplicationController
  # Telas de domínio vivem no shell autenticado (sidebar/tabs — Q63/Q65). O JSON
  # (Q73) não usa layout, então isto só afeta HTML.
  layout "app"

  before_action :set_client, only: %i[show edit update destroy]

  def index
    authorize! Client, to: :index?
    @showing_archived = params[:archived].present?

    scope = authorized_scope(Client.all)
    scope = @showing_archived ? scope.archived : scope.active
    @clients = scope.name_matching(params[:q]).alphabetical

    respond_to do |format|
      format.html
      # JSON paginado (Q73): mesmo o catálogo é limitado — um user pode acumular
      # centenas de clientes ao longo dos anos. A tela HTML segue mostrando tudo.
      format.json { @clients = paginate_json(@clients); render :index }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render :show }
    end
  end

  def new
    authorize! Client, to: :new?
    @client = authorized_scope(Client.all).new(currency: "BRL")
  end

  def edit
  end

  def create
    authorize! Client, to: :create?
    @client = authorized_scope(Client.all).new(client_params)

    if @client.save
      respond_to do |format|
        format.html { redirect_to clients_path, notice: t("clients.create.created") }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render_errors(@client) }
      end
    end
  end

  def update
    if @client.update(client_params)
      respond_to do |format|
        format.html { redirect_to clients_path, notice: t("clients.update.updated") }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_errors(@client) }
      end
    end
  end

  # Hard-delete (Q7): só é permitido SEM projetos — `dependent: :restrict_with_error`
  # no Client bloqueia quando há dependentes (destroy devolve false + erro em :base).
  # Aí a UX vira mensagem amigável ("arquive em vez de deletar"), não um 500 nem um
  # sumiço silencioso. Sem projetos → deleta normalmente.
  def destroy
    if @client.destroy
      respond_to do |format|
        format.html { redirect_to clients_path, notice: t("clients.destroy.destroyed") }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to clients_path, alert: @client.errors.full_messages.to_sentence }
        format.json { render_errors(@client) }
      end
    end
  end

  private
    def set_client
      # authorized_scope garante o isolamento por bolha (Q23): cliente de outra conta
      # simplesmente não está no escopo → RecordNotFound → 404 (não vaza existência).
      # authorize! em cima é defesa em profundidade (o piso manage? confirma o dono) e
      # honra o contrato "authorize! + authorized_scope" das ações de membro.
      @client = authorized_scope(Client.all).find(params[:id])
      authorize! @client
    end

    def client_params
      # `rate` = accessor Money (form HTML manda "150,00"; money-rails parseia p/ cents).
      # `rate_cents` = escalar int (superfície JSON/CLI — Q73). Só um vem preenchido.
      params.require(:client).permit(:name, :currency, :rate, :rate_cents, :note)
    end

    def render_errors(client)
      render json: { errors: client.errors.full_messages }, status: :unprocessable_entity
    end
end
