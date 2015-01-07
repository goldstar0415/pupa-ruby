# Download this example's [Ruby code](https://raw.githubusercontent.com/jpmckinney/pupa-ruby/gh-pages/docs/legislator.rb)
# to run locally.
#
# The [cat.rb](http://jpmckinney.github.io/pupa-ruby/docs/cat.html) example goes
# over the basics of using Pupa.rb, and [bill.rb](http://jpmckinney.github.io/pupa-ruby/docs/bill.html)
# covers how to relate objects and how to separate scraping tasks for different
# types of data. This will explain how to run, for example, different methods to
# scrape legislators depending on the legislative term - particularly useful if
# a data source changes format from year to year.
require 'pupa'

require 'nokogiri'

# parl.gc.ca uses ASP.NET forms, so we need [bigger guns](http://mechanize.rubyforge.org/).
require 'mechanize'

class LegislatorProcessor < Pupa::Processor
  # The data source publishes information from different parliaments in
  # different formats. We override `scraping_task_method` to select the method
  # used to scrape legislators according to the parliament.
  def scraping_task_method(task_name)
    if task_name == :people
      # If the task is to scrape people and a parliament is given, we select a
      # method according to the parliament.
      if @options.key?('parliament')
        if @options['parliament'].to_i >= 36
          "scrape_people_36th_to_date"
        else
          "scrape_people_1st_to_35th"
        end
      # If no parliament is given, we assume the parliament is recent, as it is
      # more common to scrape current data than historical data.
      else
        "scrape_people_36th_to_date"
      end
    # Otherwise, we use `scraping_task_method`'s default behavior for other
    # scraping tasks.
    else
      super
    end
  end

  # A helper method to put name components in a typical order.
  def swap_first_last_name(name)
    name.strip.match(/\A([^,]+?), ([^(]+?)(?: \(.+\))?\z/)[1..2].
      reverse.map{|component| component.strip.squeeze(' ')}.join(' ')
  end

  def scrape_people_36th_to_date
    url = 'http://www.parl.gc.ca/MembersOfParliament/MainMPsCompleteList.aspx?TimePeriod=Historical&Language=E'
    doc = if @options.key?('parliament')
      # Since we aren't using the default Faraday HTTP client, we manually
      # configure the Mechanize client to use Pupa.rb's logger.
      client = Mechanize.new
      client.log = Pupa::Logger.new('mechanize', level: @level)
      page = client.get(url)
      page.form['MasterPage$MasterPage$BodyContent$PageContent$Content$ListCriteriaContent$ListCriteriaContent$ucComboParliament$cboParliaments'] = @options['parliament']
      page.form.submit.parser
    else
      get(url)
    end

    doc.css('#MasterPage_MasterPage_BodyContent_PageContent_Content_ListContent_ListContent_grdCompleteList tr:gt(1)').each do |row|
      person = Pupa::Person.new
      person.name = swap_first_last_name(row.at_css('td:eq(1)').text)
      dispatch(person)
    end
  end

  def scrape_people_1st_to_35th
    list_url = 'http://www.parl.gc.ca/Parlinfo/Lists/Members.aspx?Language=E'
    page_url = 'http://www.parl.gc.ca/Parlinfo/Lists/Members.aspx?Language=E&Parliament=%s&Riding=&Name=&Party=&Province=&Gender=&New=False&Current=False&First=False&Picture=False&Section=False&ElectionDate='
    doc = get(list_url)
    value = doc.at_xpath("//select[@id='ctl00_cphContent_cboParliamentCriteria']/option[starts-with(.,'#{@options['parliament']}')]/@value").value
    doc = get(page_url % value)

    doc.css('tr:gt(1)').each do |row|
      person = Pupa::Person.new
      person.name = swap_first_last_name(row.at_css('td:eq(1)').text)
      dispatch(person)
    end
  end
end

LegislatorProcessor.add_scraping_task(:people)

# To add scraping method selection criteria when running the processor, call
# `legislator.rb` following the pattern:
#
#     ruby legislator.rb [options] -- [criteria]
#
# So, for example, to scrape and import legislators from the 37th parliament:
#
#     ruby legislator.rb -- parliament 37
#
# Or, to scrape but not import legislators from the 12th parliament:
#
#     ruby legislator.rb --action scrape -- parliament 12
runner = Pupa::Runner.new(LegislatorProcessor)
runner.run(ARGV)

# Tired of scraping and importing data? See [organization.rb](http://jpmckinney.github.io/pupa-ruby/docs/organization.html)
# to learn how to transform scraped data with Pupa.rb.
