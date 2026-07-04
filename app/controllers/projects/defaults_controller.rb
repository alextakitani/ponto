module Projects
  class DefaultsController < ApplicationController
    before_action :set_project

    def create
      if Current.user.update(default_project: @project)
        respond_to do |format|
          format.html { redirect_to projects_path, notice: "Projeto padrão definido." }
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
        format.html { redirect_to projects_path, notice: "Projeto padrão removido." }
        format.json { head :no_content }
      end
    end

    private
      def set_project
        @project = authorized_scope(Project.all).find(params[:project_id])
        authorize! @project
      end

      def render_error(message, status)
        render json: { error: message }, status: status
      end
  end
end
