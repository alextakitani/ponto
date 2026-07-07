module Tags
  class ArchivalsController < ApplicationController
    before_action :set_tag

    def create
      @tag.archive!

      respond_to do |format|
        format.html { redirect_to tags_path, notice: t("tags.archivals.created") }
        format.json { render "tags/show" }
      end
    end

    def destroy
      @tag.unarchive!

      respond_to do |format|
        format.html { redirect_to tags_path(archived: "1"), notice: t("tags.archivals.destroyed") }
        format.json { render "tags/show" }
      end
    end

    private
      def set_tag
        @tag = authorized_scope(Tag.all).find(params[:tag_id])
      end
  end
end
