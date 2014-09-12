require "rails_helper"
require "govuk/client/test_helpers/metadata_api"

feature "Info page" do
  include GOVUK::Client::TestHelpers::MetadataAPI

  scenario "Understanding the needs of a page" do
    stub_metadata_api_has_slug('apply-uk-visa', metadata_api_response_for_apply_uk_visa)

    visit "/info/apply-uk-visa"

    expect(page).to have_text("User needs")
    expect(page).to have_text("Apply for a UK visa")

    expect(page).to have_text("As non-EEA national")
    expect(page).to have_text("I need to apply for a UK visa")
    expect(page).to have_text("so that I can come to the UK to visit, study or work")

    # justification for need
    expect(page).to have_text("It's something only government does")

    # need acceptance criteria
    expect(page).to have_text("Finds out how whether they're eligible")
    expect(page).to have_text("How to apply")
    expect(page).to have_text("What documents to provide")
  end
end
