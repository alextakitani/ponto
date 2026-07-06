# Tags (Fatia 6) — catálogo irmão de Clients. Busca/ordenação por nome usam a forma
# normalizada persistida pelo concern Nameable.
class TagsController < ApplicationController
  layout "app"

  before_action :set_tag, only: %i[show edit update destroy]

  def index
    authorize! Tag, to: :index?
    @showing_archived = params[:archived].present?

    scope = authorized_scope(Tag.all)
    scope = @showing_archived ? scope.archived : scope.active
    @tags = scope.name_matching(params[:q]).alphabetical

    respond_to do |format|
      format.html
      format.json { render :index }
    end
  end

  def show
    respond_to do |format|
      format.json { render :show }
    end
  end

  def new
    authorize! Tag, to: :new?
    @tag = authorized_scope(Tag.all).new
  end

  def edit
  end

  def create
    authorize! Tag, to: :create?
    @tag = authorized_scope(Tag.all).new(tag_params)

    if @tag.save
      respond_to do |format|
        format.html { redirect_to tags_path, notice: t("tags.create.created") }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render_errors(@tag) }
      end
    end
  end

  def update
    if @tag.update(tag_params)
      respond_to do |format|
        format.html { redirect_to tags_path, notice: t("tags.update.updated") }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_errors(@tag) }
      end
    end
  end

  def destroy
    if @tag.destroy
      respond_to do |format|
        format.html { redirect_to tags_path, notice: t("tags.destroy.destroyed") }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to tags_path, alert: destroy_error_message(@tag) }
        format.json { render_errors(@tag) }
      end
    end
  end

  private
    def set_tag
      @tag = authorized_scope(Tag.all).find(params[:id])
      authorize! @tag
    end

    def tag_params
      params.require(:tag).permit(:name)
    end

    def destroy_error_message(tag)
      if tag.errors.of_kind?(:base, :restrict_dependent_destroy)
        t("tags.destroy.used_tag")
      else
        tag.errors.full_messages.to_sentence
      end
    end

    def render_errors(tag)
      render json: { errors: tag.errors.full_messages }, status: :unprocessable_entity
    end
end
