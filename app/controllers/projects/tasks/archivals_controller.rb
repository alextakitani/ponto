module Projects
  module Tasks
    # Arquivamento de task como sub-resource REST (Q7): create arquiva, destroy
    # desarquiva. Aninhado sob a rota rasa `/tasks/:task_id/archival` (shallow). Responde
    # Turbo Stream (inline, re-renderiza a seção de tasks) + HTML (fallback).
    class ArchivalsController < ApplicationController
      layout "app"

      before_action :set_task

      def create
        @task.archive!
        respond_inline notice: t("projects.tasks.archivals.created")
      end

      def destroy
        @task.unarchive!
        respond_inline notice: t("projects.tasks.archivals.destroyed")
      end

      private
        def set_task
          # Escopado pra bolha do user (Q23): task alheia não está no escopo → 404.
          @task = authorized_scope(Task.all).find(params[:task_id])
        end

        # Re-renderiza a seção de tasks do projeto (Turbo Frame) ou cai no redirect HTML.
        def respond_inline(notice:)
          @project = @task.project
          @tasks = @project.active_tasks

          respond_to do |format|
            # Mesma seção que o CRUD inline re-renderiza — via o partial de stream
            # compartilhado (ver `_section_stream`). `@tasks` já materializado → sem
            # query dupla no `_section`.
            format.turbo_stream do
              render "projects/tasks/section_stream", project: @project, tasks: @tasks
            end
            format.html { redirect_to edit_project_path(@project), notice: notice }
          end
        end
    end
  end
end
