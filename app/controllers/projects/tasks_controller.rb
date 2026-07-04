module Projects
  # Tasks (Fatia 2.3) — sub-bucket do Project (Q1), gerenciadas INLINE no show/edit do
  # projeto (TELA 02), sem tela própria no sidebar. Rotas aninhadas + shallow: create/
  # new/index carregam o project pelo `project_id`; member (edit/update/destroy) usa a
  # rota rasa `/tasks/:id`. O CRUD responde Turbo Stream (inline) + HTML (fallback) +
  # JSON (Q73). Isolamento por bolha (Q23): tudo escopado por Current.user.
  class TasksController < ApplicationController
    layout "app"

    before_action :set_project, only: %i[index new create]
    before_action :set_task, only: %i[show edit update destroy]

    def index
      @tasks = @project.active_tasks

      respond_to do |format|
        format.html { redirect_to edit_project_path(@project) }
        format.json { render :index }
      end
    end

    def show
      respond_to do |format|
        format.html { redirect_to edit_project_path(@task.project) }
        format.json { render :show }
      end
    end

    def new
      @task = @project.tasks.new
    end

    # Renomear inline: o Turbo Stream troca a linha da task pelo form de edição.
    def edit
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_project_path(@task.project) }
      end
    end

    def create
      authorize! Task, to: :create?
      @task = @project.tasks.new(task_params.merge(user: Current.user))

      if @task.save
        respond_to do |format|
          format.turbo_stream { render :create }
          format.html { redirect_to edit_project_path(@project), notice: t("projects.tasks.create.created") }
          format.json { render :show, status: :created }
        end
      else
        respond_to do |format|
          format.turbo_stream { render :new, status: :unprocessable_entity }
          format.html { redirect_to edit_project_path(@project), alert: @task.errors.full_messages.to_sentence }
          format.json { render_errors(@task) }
        end
      end
    end

    def update
      if @task.update(task_params)
        respond_to do |format|
          format.turbo_stream { render :update }
          format.html { redirect_to edit_project_path(@task.project), notice: t("projects.tasks.update.updated") }
          format.json { render :show }
        end
      else
        respond_to do |format|
          format.turbo_stream { render :edit, status: :unprocessable_entity }
          format.html { redirect_to edit_project_path(@task.project), alert: @task.errors.full_messages.to_sentence }
          format.json { render_errors(@task) }
        end
      end
    end

    # Hard-delete da task: estrutura, não histórico — some (a Fase 3/TimeEntry vai
    # restringir se houver entries apontando pra ela). Some inline via Turbo Stream.
    def destroy
      @project = @task.project
      @task.destroy

      respond_to do |format|
        format.turbo_stream { render :destroy }
        format.html { redirect_to edit_project_path(@project), notice: t("projects.tasks.destroy.destroyed") }
        format.json { head :no_content }
      end
    end

    private
      def set_project
        # Escopado pra bolha (Q23): projeto alheio não está no escopo → 404 (não vaza).
        @project = authorized_scope(Project.all).find(params[:project_id])
      end

      def set_task
        @task = authorized_scope(Task.all).find(params[:id])
        authorize! @task
      end

      def task_params
        params.require(:task).permit(:name)
      end

      def render_errors(task)
        render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
      end
  end
end
