# frozen_string_literal: true

class CalendarEvent < ActiveRecord::Base
  belongs_to :topic
  belongs_to :post
  belongs_to :user

  def self.update(post)
    CalendarEvent.where(post_id: post.id).destroy_all

    dates = post.local_dates
    return if dates.size < 1 || dates.size > 2

    from = self.convert_to_date_time(dates[0])
    to = self.convert_to_date_time(dates[1]) if dates.size == 2

    adjust_to = !to || !dates[1]['time']
    if !to && dates[0]['time']
      to = from + 1.hour
      artificial_to = true
    end

    if SiteSetting.all_day_event_start_time.present? && SiteSetting.all_day_event_end_time.present?
      from = from.change(hour_adjustment(SiteSetting.all_day_event_start_time)) if !dates[0]['time']
      to = (to || from).change(hour_adjustment(SiteSetting.all_day_event_end_time)) if adjust_to && !artificial_to
    end

    doc = Nokogiri::HTML::fragment(post.cooked)
    doc.css('.discourse-local-date').each(&:remove)
    html = doc.to_html.sub(' → ', '')

    description = PrettyText.excerpt(html, 1000, strip_links: true, text_entities: true, keep_emoji_images: true)
    recurrence = dates[0]['recurring'].presence

    CalendarEvent.create!(
      topic_id: post.topic_id,
      post_id: post.id,
      post_number: post.post_number,
      user_id: post.user_id,
      username: post.user.username,
      description: description,
      start_date: from,
      end_date: to,
      recurrence: recurrence
    )

    post.publish_change_to_clients!(:calendar_change)
  end

  private

  def self.convert_to_date_time(value)
    return if value.blank?

    datetime = value['date'].to_s
    datetime << " #{value['time']}" if value['time']
    timezone = value['timezone'] || 'UTC'

    ActiveSupport::TimeZone[timezone].parse(datetime)
  end

  def self.hour_adjustment(setting)
    setting = setting.split(':')

    { hour: setting.first, min: setting.last }
  end
end

# == Schema Information
#
# Table name: calendar_events
#
#  id          :bigint           not null, primary key
#  topic_id    :integer          not null
#  post_id     :integer
#  post_number :integer
#  user_id     :integer
#  username    :string
#  description :string
#  start_date  :datetime         not null
#  end_date    :datetime
#  recurrence  :string
#  region      :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_calendar_events_on_post_id   (post_id)
#  index_calendar_events_on_topic_id  (topic_id)
#  index_calendar_events_on_user_id   (user_id)
#