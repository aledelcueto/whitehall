require "test_helper"
require "gds_api/test_helpers/publishing_api"

class SchedulingTest < ActiveSupport::TestCase
  include GdsApi::TestHelpers::PublishingApi

  setup do
    @submitted_edition = create(:submitted_case_study,
                                scheduled_publication: 1.day.from_now)

    Sidekiq::Testing.inline!

    stub_legacy_sidekiq_scheduling
    stub_any_publishing_api_call
    stub_default_publishing_api_put_intent
  end

  test "scheduling a first-edition publishes a publish intent and 'coming_soon' content item to the Publishing API" do
    coming_soon_uuid = SecureRandom.uuid
    SecureRandom.stubs(uuid: coming_soon_uuid)

    path = Whitehall.url_maker.public_document_path(@submitted_edition)
    schedule(@submitted_edition)
    assert_publishing_api_put_content(coming_soon_uuid,
                                      request_json_includes(schema_name: 'coming_soon'))
    assert_publishing_api_put_intent(path, publish_time: @submitted_edition.scheduled_publication.as_json)
  end

  test "scheduling a subsequent edition publishes a publish intent to the Publishing API" do
    published_edition = create(:published_case_study)
    new_draft = published_edition.create_draft(published_edition.creator)
    new_draft.change_note = 'changed'
    new_draft.scheduled_publication = 1.day.from_now
    new_draft.save!
    new_draft.submit!

    path = Whitehall.url_maker.public_document_path(new_draft)

    acting_as(create(:user)) { schedule(new_draft) }

    assert_not_requested(:put, %r{#{PUBLISHING_API_V2_ENDPOINT}/content.*})
    assert_publishing_api_put_intent(path, publish_time: new_draft.scheduled_publication.as_json)
  end

  test "scheduling a translated edition publishes a publish intent for each translation" do
    I18n.with_locale :fr do
      @submitted_edition.title = "French title"
      @submitted_edition.save!
    end

    english_path = Whitehall.url_maker.public_document_path(@submitted_edition)
    french_path  = Whitehall.url_maker.public_document_path(@submitted_edition, locale: :fr)
    publish_time = @submitted_edition.scheduled_publication.as_json

    schedule(@submitted_edition)

    assert_publishing_api_put_intent(english_path, publish_time: publish_time)
    assert_publishing_api_put_intent(french_path, publish_time: publish_time)
  end

  test "unscheduling a scheduled first-edition removes the publish intent and replaces the 'coming_soon' with a 'gone' item" do
    gone_uuid = SecureRandom.uuid
    SecureRandom.stubs(uuid: gone_uuid)
    scheduled_edition = create(:scheduled_case_study)
    unscheduler       = Whitehall.edition_services.unscheduler(scheduled_edition)
    base_path         = Whitehall.url_maker.public_document_path(scheduled_edition)

    destroy_intent_request = stub_publishing_api_destroy_intent(base_path)
    gone_request = stub_publishing_api_unpublish(
      scheduled_edition.content_id,
      body: {
        type: "gone",
        locale: "en",
        discard_drafts: true,
      }
    )

    unscheduler.perform!

    assert_requested destroy_intent_request
    assert_requested gone_request
  end

  test "unscheduling a scheduled subsequent edition removes the publish intent but doesn't publish a 'gone' item" do
    published_edition = create(:published_case_study)
    scheduled_edition = create(:scheduled_case_study, document: published_edition.document)

    unscheduler       = Whitehall.edition_services.unscheduler(scheduled_edition)
    base_path         = Whitehall.url_maker.public_document_path(scheduled_edition)

    destroy_intent_request = stub_publishing_api_destroy_intent(base_path)

    unscheduler.perform!

    assert_requested destroy_intent_request
    assert_not_requested(:put, %r{#{PUBLISHING_API_ENDPOINT}/content.*})
  end

private
  def schedule(edition, options = {})
    Whitehall.edition_services.scheduler(edition, options).perform!
  end

  def stub_legacy_sidekiq_scheduling
    # Scheduling an item will enqueue the publish action, and queued actions
    # are performed immediately in test, which will fail: so stub the worker.
    ScheduledPublishingWorker.stubs(:queue)
  end
end
