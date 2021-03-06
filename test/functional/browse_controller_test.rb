require_relative "../test_helper"

class BrowseControllerTest < ActionController::TestCase
  setup do
    # Stub out the website_root to make sure we are providing a
    # consistent root for the site URL, regardless of environment.
    #
    # The website root is hard-coded in the test helpers, so it gets hard-coded
    # here too.
    Plek.any_instance.stubs(:website_root).returns("http://www.test.gov.uk")
  end

  context "GET index" do
    should "list all categories" do
      content_api_has_root_sections(["crime-and-justice"])
      get :index
      assert_select "ul h2 a", "Crime and justice"
      assert_select "ul h2 a[href=/browse/crime-and-justice]"
    end

    should "set slimmer format of browse" do
      content_api_has_root_sections(["crime-and-justice"])
      get :index

      assert_equal "browse",  response.headers["X-Slimmer-Format"]
    end

    should "set correct expiry headers" do
      content_api_has_root_sections(["crime-and-justice"])
      get :index

      assert_equal "max-age=1800, public",  response.headers["Cache-Control"]
    end

    should "handle unescaped descriptions from the content API" do
      section = {
        slug: "education",
        title: "Education and learning",
        description: "Get help & support."
      }
      content_api_has_root_sections([section])

      get :index
      assert_response :success
      assert response.body.include? "Get help &amp; support."
    end
  end

  context "GET section" do
    should "list the sub sections" do
      content_api_has_section("crime-and-justice")
      content_api_has_subsections("crime-and-justice", ["alpha"])
      get :section, section: "crime-and-justice"

      assert_select "h1", "Crime and justice"
      assert_select "ul h2 a[href=/browse/alpha]"
    end

    should "404 if the section does not exist" do
      api_returns_404_for("/tags/banana.json")
      api_returns_404_for("/tags.json?parent_id=banana&type=section")

      get :section, section: "banana"
      assert_response 404
    end

    should "return a cacheable 404 without calling content_api if the section slug is invalid" do
      get :section, section: "this & that"
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      get :section, section: "fco\xA0" # Invalid UTF-8
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      get :section, section: "br54ba\x9CAQ\xC4\xFD\x928owse" # Malformed UTF-8
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      get :section, section: "\xE9\xF3(\xE9\xF3ges" # Differently Malformed UTF-8
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      assert_not_requested(:get, %r{\A#{CONTENT_API_ENDPOINT}})
    end

    should "set slimmer format of browse" do
      content_api_has_section("crime-and-justice")
      content_api_has_subsections("crime-and-justice", ["alpha"])
      get :section, section: "crime-and-justice"

      assert_equal "browse",  response.headers["X-Slimmer-Format"]
    end

    should "set correct expiry headers" do
      content_api_has_section("crime-and-justice")
      content_api_has_subsections("crime-and-justice", ["alpha"])
      get :section, section: "crime-and-justice"

      assert_equal "max-age=1800, public",  response.headers["Cache-Control"]
    end

    should "handle unescaped section descriptions" do
      section = {
        slug: "education",
        title: "Education and learning",
        description: "Get help & support."
      }
      content_api_has_section(section)
      content_api_has_subsections(section, ["alpha"])

      get :section, section: "education"
      assert_response :success
      assert response.body.include? "Get help &amp; support."
    end

    should "handle unescaped subsection descriptions" do
      subsection = {
        slug: "education/science",
        title: "For science!",
        description: "Science & education & other good things."
      }
      content_api_has_section("education")
      content_api_has_subsections("education", [subsection])

      get :section, section: "education"
      assert_response :success
      assert response.body.include? "Science &amp; education &amp; other good things."
    end
  end

  context "GET sub_section" do
    setup do
      mock_api = stub('guidance_api')
      @results = stub("results", results: [])
      mock_api.stubs(:sub_sections).returns(@results)
      Frontend.stubs(:detailed_guidance_content_api).returns(mock_api)
    end

    should "list the content in the sub section" do
      content_api_has_section("crime-and-justice/judges", "crime-and-justice")
      content_api_has_artefacts_in_a_section("crime-and-justice/judges", ["judge-dredd"])

      get :sub_section, section: "crime-and-justice", sub_section: "judges"

      assert_select "h1", "Judges"
      assert_select "li h3 a", "Judge dredd"
    end

    should "list detailed guidance categories in the sub section" do
      content_api_has_section("crime-and-justice/judges", "crime-and-justice")
      content_api_has_artefacts_in_a_section("crime-and-justice/judges", ["judge-dredd"])

      detailed_guidance = OpenStruct.new({
          title: 'Detailed guidance',
          details: OpenStruct.new(description: "Lorem Ipsum Dolor Sit Amet"),
          content_with_tag: OpenStruct.new(web_url: 'http://example.com/browse/detailed-guidance')
        })

      @results.stubs(:results).returns([detailed_guidance])

      get :sub_section, section: "crime-and-justice", sub_section: "judges"

      assert_select '.detailed-guidance' do
        assert_select "li a[href='http://example.com/browse/detailed-guidance']", text: 'Detailed guidance'
        assert_select 'li p', text: "Lorem Ipsum Dolor Sit Amet"
      end
    end

    should "404 if the section does not exist" do
      api_returns_404_for("/tags/crime-and-justice%2Ffrume.json")
      api_returns_404_for("/tags/crime-and-justice.json")

      get :sub_section, section: "crime-and-justice", sub_section: "frume"
      assert_response 404
    end

    should "return a cacheable 404 without calling content_api if the section slug is invalid" do
      get :sub_section, section: "this & that", sub_section: "foo"
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      get :sub_section, section: "fco\xA0", sub_section: "foo" # Invalid UTF-8
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      get :sub_section, section: "br54ba\x9CAQ\xC4\xFD\x928owse", sub_section: "foo" # Malformed UTF-8
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      get :sub_section, section: "\xE9\xF3(\xE9\xF3ges", sub_section: "foo" # Differently Malformed UTF-8
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      assert_not_requested(:get, %r{\A#{CONTENT_API_ENDPOINT}})
    end

    should "404 if the sub section does not exist" do
      content_api_has_section("crime-and-justice")
      api_returns_404_for("/tags/crime-and-justice%2Ffrume.json")
      get :sub_section, section: "crime-and-justice", sub_section: "frume"
      assert_response 404
    end

    should "return a cacheable 404 without calling content_api if the sub section slug is invalid" do
      get :sub_section, section: "foo", sub_section: "this & that"
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      get :sub_section, section: "foo", sub_section: "fco\xA0" # Invalid UTF-8
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      get :sub_section, section: "foo", sub_section: "br54ba\x9CAQ\xC4\xFD\x928owse" # Malformed UTF-8
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      get :sub_section, section: "foo", sub_section: "\xE9\xF3(\xE9\xF3ges" # Differently Malformed UTF-8
      assert_equal "404", response.code
      assert_equal "max-age=600, public",  response.headers["Cache-Control"]

      assert_not_requested(:get, %r{\A#{CONTENT_API_ENDPOINT}})
    end

    should "set slimmer format of browse" do
      content_api_has_section("crime-and-justice/judges", "crime-and-justice")
      content_api_has_artefacts_in_a_section("crime-and-justice/judges", ["judge-dredd"])
      get :sub_section, section: "crime-and-justice", sub_section: "judges"

      assert_equal "browse",  response.headers["X-Slimmer-Format"]
    end

    should "set correct expiry headers" do
      content_api_has_section("crime-and-justice/judges", "crime-and-justice")
      content_api_has_artefacts_in_a_section("crime-and-justice/judges", ["judge-dredd"])
      get :sub_section, section: "crime-and-justice", sub_section: "judges"

      assert_equal "max-age=1800, public",  response.headers["Cache-Control"]
    end
  end
end
