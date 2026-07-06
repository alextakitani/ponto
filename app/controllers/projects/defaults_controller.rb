module Projects
  class DefaultsController < ApplicationController
    before_action :set_project

    def create
      if Current.user.update(default_project: @project)
        respond_to do |format|
          format.turbo_stream { render_default_change t("projects.defaults.created") }
          format.html { redirect_to projects_path, notice: t("projects.defaults.created") }
          format.json { render json: { default_project_id: @project.id }, status: :created }
        end
      else
        respond_to do |format|
          format.html { redirect_to projects_path, alert: Current.user.errors.full_messages.to_sentence, status: :see_other }
          format.json { render_error(Current.user.errors.full_messages.to_sentence, :unprocessable_entity) }
        end
      end
    end

    def destroy
      Current.user.update(default_project: nil) if Current.user.default_project_id == @project.id

      respond_to do |format|
        format.turbo_stream { render_default_change t("projects.defaults.destroyed") }
        format.html { redirect_to projects_path, notice: t("projects.defaults.destroyed") }
        format.json { head :no_content }
      end
    end

    private
      # Reflete a troca de padrão sem refresh: atualiza a lista de projetos (badge
      # "Padrão") e — SÓ se não houver timer rodando — a barra do timer, pra o
      # select pré-selecionar o novo padrão. Com timer rodando a barra mostra o
      # cronômetro (sem select) e não deve ser tocada (não reinicia o relógio).
      def render_default_change(notice)
        # MESMA ordenação da index (ProjectsController#index): Nameable.alphabetical.
        @projects = authorized_scope(Project.all).active.includes(:client).alphabetical
        @running_timer = authorized_scope(TimeEntry.all).exists?(ended_at: nil)
        flash.now[:notice] = notice
        render "projects/defaults/update"
      end

      def set_project
        @project = authorized_scope(Project.all).find(params[:project_id])
        authorize! @project
      end

      def render_error(message, status)
        render json: { error: message }, status: status
      end
  end
end
