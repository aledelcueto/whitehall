module SyncChecker
  module Formats
    class DocumentCollectionCheck < EditionBase
      def root_path
        "/government/collections/"
      end

      def rendering_app
        Whitehall::RenderingApp::GOVERNMENT_FRONTEND
      end

      def checks_for_draft(locale)
        super + [
          Checks::LinksCheck.new(
            "topical_events",
            TopicalEvent
              .for_edition(edition_expected_in_draft.id)
              .pluck(:content_id)
          ),
          Checks::LinksCheck.new(
            "documents",
            draft_linked_document_content_ids(edition_expected_in_draft)
          )
        ]
      end

      def checks_for_live(locale)
        super + [
          Checks::LinksCheck.new(
            "topical_events",
            TopicalEvent
              .for_edition(edition_expected_in_live.id)
              .pluck(:content_id)
          ),
          Checks::LinksCheck.new(
            "documents",
            linked_document_content_ids(edition_expected_in_live)
          )
        ]
      end

      def expected_details_hash(edition, _)
        super.merge(
          collection_groups: collection_groups(edition)
        )
      end

    private

      def collection_groups(edition)
        edition.groups.map do |group|
          {
            title: group.heading,
            body: govspeak_renderer.govspeak_to_html(group.body),
            documents: group.documents.collect(&:content_id)
          }.stringify_keys
        end
      end

      def govspeak_renderer
        @govspeak_renderer ||= Whitehall::GovspeakRenderer.new
      end

      def linked_document_content_ids(edition)
        edition.documents
          .select { |document| latest_edition_published?(document) }
          .map(&:content_id)
      end

      def draft_linked_document_content_ids(edition)
        edition.documents
          .reject { |document| document_is_deleted?(document) }
          .map(&:content_id)
      end

      def document_is_deleted?(document)
        Edition
          .unscoped
          .where(document_id: document.id)
          .pluck(:state)
          .last == "deleted"
      end

      def latest_edition_published?(document)
        document.published_edition && !document.published_edition.withdrawn?
      end
    end
  end
end
