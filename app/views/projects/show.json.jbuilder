# Show do Project em JSON (Q73): o projeto + suas tasks ATIVAS aninhadas (array de
# escalares). @tasks vem ordenado do controller.
json.partial! "projects/project", project: @project
json.tasks @tasks, partial: "projects/tasks/task", as: :task
