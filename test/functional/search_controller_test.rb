require "test_helper"

class SearchControllerTest < ActionController::TestCase
  should_be_a_public_facing_controller

  test "should inform the user that we didn't find any documents matching the search term" do
    client = stub("search", search: [])
    Whitehall::SearchClient.stubs(:new).returns(client)
    get :index, q: "search-term"
    assert_select "p", text: %Q{We can't find any results for "search-term".}
  end

  test "should pass our query parameter in to the search client" do
    client = stub("search")
    Whitehall::SearchClient.stubs(:new).returns(client)
    client.expects(:search).with("search-term").returns([])
    get :index, q: "search-term"
  end

  test "should include the term we search for in the page header" do
    client = stub("search", search: [])
    Whitehall::SearchClient.stubs(:new).returns(client)
    get :index, q: "search-term"
    assert_select "h1", text: /search-term/
  end

  test "should display the number of results" do
    client = stub("search", search: [{}, {}, {}])
    Whitehall::SearchClient.stubs(:new).returns(client)
    get :index
    assert_select "h1", text: /3 results/
  end

  test "should display a link to the documents matching our search criteria" do
    client = stub("search", search: [{"title" => "document-title", "link" => "/document-slug"}])
    Whitehall::SearchClient.stubs(:new).returns(client)
    get :index
    assert_select "a[href='/document-slug']", text: "document-title"
  end

  test "should display the highlighted text from the search result" do
    client = stub("search", search: [{"title" => "title", "link" => "/slug", "highlight" => "the HIGHLIGHT_STARTmatchHIGHLIGHT_END for"}])
    Whitehall::SearchClient.stubs(:new).returns(client)
    get :index
    assert_select ".highlight", text: "&hellip;the match for&hellip;" do
      assert_select "strong", text: "match"
    end
  end
end