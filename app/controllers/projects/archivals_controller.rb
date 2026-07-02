module Projects
  # Arquivamento de projeto como sub-resource REST (Q7): create arquiva, destroy
  # desarquiva. Espelha o Clients::ArchivalsController — ação sem verbo padrão vira
  # sub-resource, não custom action (STYLE.md). A soft-delete mora no Archivable.
  class ArchivalsController < ApplicationController
    before_action :set_project

    def create
      @project.archive!
      redirect_to projects_path, notice: "Projeto arquivado."
    end

    def destroy
      @project.unarchive!
      redirect_to projects_path(archived: "1"), notice: "Projeto desarquivado."
    end

    private
      def set_project
        # Escopado pra bolha do user (Q23): projeto alheio não está no escopo → 404.
        @project = authorized_scope(Project.all).find(params[:project_id])
      end
  end
end
