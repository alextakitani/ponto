# Projetos (Fatia 2.3) — irmão do Client. Controller fino sobre o model rico
# (STYLE.md): a policy resolve pode/não-pode e o `authorized_scope` filtra pra bolha
# do user (Q23). Responde HTML (telas no shell) e JSON (Q73 — escalares, nunca Money
# cru — Q11). O show carrega as tasks aninhadas (TELA 02).
class ProjectsController < ApplicationController
  layout "app"

  before_action :set_project, only: %i[show edit update destroy]

  def index
    authorize! Project, to: :index?
    @showing_archived = params[:archived].present?

    scope = authorized_scope(Project.all).includes(:client)
    scope = @showing_archived ? scope.archived : scope.active
    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
    # Busca por nome EM RUBY: `name` é criptografado (Q25c) → LIKE não casa o
    # ciphertext. Catálogo pequeno (Q39/Q50); ordenar/filtrar em memória é barato.
    @projects = filter_by_name(scope.to_a, params[:q]).sort_by { |p| p.name.downcase }
    # Clientes ATIVOS pro select de filtro (label pt-BR ordenado em Ruby — name cifrado).
    @clients = authorized_scope(Client.all).active.to_a.sort_by { |c| c.name.downcase }

    respond_to do |format|
      format.html
      format.json { render :index }
    end
  end

  def show
    @tasks = @project.tasks.active.to_a.sort_by { |t| t.name.downcase }

    respond_to do |format|
      format.html
      format.json { render :show }
    end
  end

  def new
    authorize! Project, to: :new?
    @project = authorized_scope(Project.all).new
    load_client_options
  end

  def edit
    load_client_options
  end

  def create
    authorize! Project, to: :create?
    @project = authorized_scope(Project.all).new(project_params)

    if @project.save
      respond_to do |format|
        format.html { redirect_to projects_path, notice: "Projeto criado." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { load_client_options; render :new, status: :unprocessable_entity }
        format.json { render_errors(@project) }
      end
    end
  end

  def update
    if @project.update(project_params)
      respond_to do |format|
        format.html { redirect_to projects_path, notice: "Projeto atualizado." }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { load_client_options; render :edit, status: :unprocessable_entity }
        format.json { render_errors(@project) }
      end
    end
  end

  # Hard-delete (Q7): permitido POR ORA — não existem TimeEntries ainda apontando pro
  # projeto. As tasks são estrutura, então caem junto (`dependent: :destroy`). ⚠️ A
  # Fase 3 (TimeEntry) adiciona `restrict` aqui: projeto com entries só arquiva.
  def destroy
    @project.destroy
    respond_to do |format|
      format.html { redirect_to projects_path, notice: "Projeto removido." }
      format.json { head :no_content }
    end
  end

  private
    def set_project
      # authorized_scope garante o isolamento (Q23): projeto de outra conta não está
      # no escopo → RecordNotFound → 404 (não vaza existência). authorize! em cima é
      # defesa em profundidade (o piso manage? confirma o dono).
      @project = authorized_scope(Project.all).find(params[:id])
      authorize! @project
    end

    def project_params
      # `rate` = writer pt-BR do form ("150,00"); `rate_cents` = escalar int (JSON/CLI
      # — Q73). client_id e color vêm do form (swatch radio). Só um de rate/rate_cents
      # vem preenchido.
      params.require(:project).permit(:name, :color, :client_id, :rate, :rate_cents)
    end

    # Clientes ATIVOS do user pro select do form + o ATUAL mesmo arquivado (Q45: o
    # projeto pode já apontar um cliente arquivado — não some do dropdown ao editar).
    def load_client_options
      active = authorized_scope(Client.all).active.to_a
      current = @project.client
      clients = current && current.archived? ? active + [ current ] : active
      @client_options = clients.uniq.sort_by { |c| c.name.downcase }
    end

    def filter_by_name(projects, query)
      if query.present?
        needle = query.strip.downcase
        projects.select { |p| p.name.downcase.include?(needle) }
      else
        projects
      end
    end

    def render_errors(project)
      render json: { errors: project.errors.full_messages }, status: :unprocessable_entity
    end
end
