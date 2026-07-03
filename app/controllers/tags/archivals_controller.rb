module Tags
  class ArchivalsController < ApplicationController
    before_action :set_tag

    def create
      @tag.archive!
      redirect_to tags_path, notice: "Tag arquivada."
    end

    def destroy
      @tag.unarchive!
      redirect_to tags_path(archived: "1"), notice: "Tag desarquivada."
    end

    private
      def set_tag
        @tag = authorized_scope(Tag.all).find(params[:tag_id])
      end
  end
end
