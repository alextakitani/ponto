require "test_helper"

class TaggingTest < ActiveSupport::TestCase
  setup do
    @user = create_user(email: "dono@example.com")
  end

  test "tagging exige tag e time_entry da mesma bolha" do
    other = create_user(email: "outro@example.com")
    foreign_tag = other.tags.create!(name: "Alheia")
    entry = @user.time_entries.create!(
      started_at: Time.current - 1.hour,
      ended_at: Time.current
    )

    tagging = Tagging.new(tag: foreign_tag, time_entry: entry)

    assert_not tagging.valid?
    assert_includes tagging.errors[:tag], "não pertence a você"
  end

  test "índice único impede taggear o mesmo entry duas vezes com a mesma tag" do
    tag = @user.tags.create!(name: "Bug")
    entry = @user.time_entries.create!(
      started_at: Time.current - 1.hour,
      ended_at: Time.current
    )

    Tagging.create!(tag:, time_entry: entry)
    duplicate = Tagging.new(tag:, time_entry: entry)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tag_id], "já está em uso"
  end
end
