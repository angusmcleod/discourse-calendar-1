# frozen_string_literal: true

module Jobs
  class DiscoursePostEventEventWillStart < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      raise Discourse::InvalidParameters.new(:event_id) if args[:event_id].blank?
      event = DiscoursePostEvent::Event.find(args[:event_id])
      DiscourseEvent.trigger(:discourse_post_event_event_will_start, event)
    end
  end
end