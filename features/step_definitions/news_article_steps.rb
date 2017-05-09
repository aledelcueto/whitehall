Given(/^a published news article "([^"]*)" with related published policies "([^"]*)" and "([^"]*)"$/) do |news_article_title, policy_title_1, policy_title_2|
  policies = publishing_api_has_policies([policy_title_1, policy_title_2])

  create(:published_news_article, title: news_article_title, policy_content_ids: policies.map {|p| p['content_id']})
end

Given(/^a published news article "([^"]*)" associated with "([^"]*)"$/) do |title, appointee|
  person = find_person(appointee)
  appointment = find_person(appointee).current_role_appointments.last
  create(:published_news_article, title: title, role_appointments: [appointment])
end

Given(/^a published news article "([^"]*)" which is not explicitly associated with "([^"]*)"$/) do |title, thing|
  create(:published_news_article, title: title)
end

When(/^I draft a new news article "([^"]*)"$/) do |title|
  begin_drafting_news_article title: title, summary: "here's a simple summary"
  within ".images" do
    attach_file "File", jpg_image, match: :first
    fill_in "Alt text", with: 'An alternative description', match: :first
  end
  click_button "Save"
end

When(/^I draft a new news article "([^"]*)" relating it to the policies "([^"]*)" and "([^"]*)"$/) do |title, first_policy, second_policy|
  publishing_api_has_policies([first_policy, second_policy])

  begin_drafting_news_article title: title
  select first_policy, from: "Policies"
  select second_policy, from: "Policies"
  click_button "Save"
end

When(/^I publish a news article "([^"]*)" associated with "([^"]*)"$/) do |title, person_name|
  begin_drafting_news_article title: title
  fill_in_news_article_fields(first_published: Date.today.to_s)
  select person_name, from: "Ministers"
  click_button "Save"
  publish(force: true)
end

When(/^I publish a news article "([^"]*)" associated with the (topic|topical event) "([^"]*)"$/) do |title, type, topic_name|
  begin_drafting_news_article title: title, skip_topic_selection: (type == 'topic')

  if type == 'topic'
    select topic_name, from: "Policy Areas"
  else
    select topic_name, from: "Topical events"
  end

  fill_in_news_article_fields(first_published: Date.today.to_s)
  click_button "Save"
  publish(force: true)
end

When(/^I publish a news article "(.*?)" associated with the organisation "(.*?)"$/) do |title, organisation_name|
  begin_drafting_news_article title: title
  fill_in_news_article_fields(first_published: Date.today.to_s)
  within '.lead-organisations' do
    select organisation_name, from: "Organisation 1"
  end
  click_button "Save"
  publish(force: true)
end

When(/^I attempt to add the article image into the markdown$/) do
  fill_in "Body", with: "body copy\n!!1\nmore body"
end

Then(/^the news article tag is the same as the person in the text$/) do
  visit admin_edition_path(NewsArticle.last)
  click_button "Create new edition"
  appointment = NewsArticle.last.role_appointments.first
  assert has_css?("select#edition_role_appointment_ids option[value='#{appointment.id}'][selected=selected]")
end

Then(/^I should see both the news articles for the Deputy Prime Minister role$/) do
  assert has_css?(".news_article", text: "News from Don, Deputy PM")
  assert has_css?(".news_article", text: "News from Harriet, Deputy PM")
end

Then(/^I should see both the news articles for Harriet Home$/) do
  assert has_css?(".news_article", text: "News from Harriet, Deputy PM")
  assert has_css?(".news_article", text: "News from Harriet, Home Sec")
end

Then(/^I should be informed I should not use this image in the markdown$/) do
  click_on "Edit draft"
  assert has_no_css?("fieldset#image_fields .image input[value='!!1']")
end

When(/^I browse to the announcements index$/) do
  visit announcements_path
end

When(/^I publish a new news article of the type "(.*?)" called "(.*?)"$/) do |announcement_type, title|
  begin_drafting_news_article(title: title, first_published: Date.today.to_s, announcement_type: announcement_type)
  click_button "Save"
  publish(force: true)
end

When(/^I filter the announcements list by "(.*?)"$/) do |announcement_type|
  visit announcements_path
  select announcement_type, from: "Announcement type"
  click_on "Refresh results"
end
