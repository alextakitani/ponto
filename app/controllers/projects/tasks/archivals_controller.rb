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
        respond_inline notice: "Tarefa arquivada."
      end

      def destroy
        @task.unarchive!
        respond_inline notice: "Tarefa desarquivada."
      end

      private
        def set_task
          # Escopado pra bolha do user (Q23): task alheia não está no escopo → 404.
          @task = authorized_scope(Task.all).find(params[:task_id])
        end

        # Re-renderiza a seção de tasks do projeto (Turbo Frame) ou cai no redirect HTML.
        def respond_inline(notice:)
          @project = @task.project
          @tasks = @project.tasks.active.to_a.sort_by { |t| t.name.downcase }

          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.replace(
                "project_tasks", partial: "projects/tasks/section", locals: { project: @project }
              )
            end
            format.html { redirect_to edit_project_path(@project), notice: notice }
          end
        end
    end
  end
end
