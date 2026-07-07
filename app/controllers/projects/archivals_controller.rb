module Projects
  # Arquivamento de projeto como sub-resource REST (Q7): create arquiva, destroy
  # desarquiva. Espelha o Clients::ArchivalsController — ação sem verbo padrão vira
  # sub-resource, não custom action (STYLE.md). A soft-delete mora no Archivable.
  class ArchivalsController < ApplicationController
    before_action :set_project

    def create
      @project.archive!
      @tasks = @project.active_tasks

      respond_to do |format|
        format.html { redirect_to projects_path, notice: t("projects.archivals.created") }
        format.json { render "projects/show" }
      end
    end

    def destroy
      @project.unarchive!
      @tasks = @project.active_tasks

      respond_to do |format|
        format.html { redirect_to projects_path(archived: "1"), notice: t("projects.archivals.destroyed") }
        format.json { render "projects/show" }
      end
    end

    private
      def set_project
        # Escopado pra bolha do user (Q23): projeto alheio não está no escopo → 404.
        @project = authorized_scope(Project.all).find(params[:project_id])
      end
  end
end
