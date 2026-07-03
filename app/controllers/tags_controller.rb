# Tags (Fatia 6) — catálogo irmão de Clients. Busca/ordenação por nome rodam em Ruby
# porque `name` é criptografado deterministic e o LIKE/ORDER do banco operariam no
# ciphertext, não no valor em claro.
class TagsController < ApplicationController
  layout "app"

  before_action :set_tag, only: %i[show edit update destroy]

  def index
    authorize! Tag, to: :index?
    @showing_archived = params[:archived].present?

    scope = authorized_scope(Tag.all)
    scope = @showing_archived ? scope.archived : scope.active
    @tags = filter_by_name(scope.to_a, params[:q]).sort_by { |tag| tag.name.downcase }

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
        format.html { redirect_to tags_path, notice: "Tag criada." }
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
        format.html { redirect_to tags_path, notice: "Tag atualizada." }
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
        format.html { redirect_to tags_path, notice: "Tag removida." }
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

    def filter_by_name(tags, query)
      if query.present?
        needle = query.strip.downcase
        tags.select { |tag| tag.name.downcase.include?(needle) }
      else
        tags
      end
    end

    def destroy_error_message(tag)
      if tag.errors.of_kind?(:base, :restrict_dependent_destroy)
        "Esta tag já foi usada em entradas. Arquive-a em vez de deletar."
      else
        tag.errors.full_messages.to_sentence
      end
    end

    def render_errors(tag)
      render json: { errors: tag.errors.full_messages }, status: :unprocessable_entity
    end
end
