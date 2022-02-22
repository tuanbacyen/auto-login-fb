# gem install selenium-webdriver chromedriver-helper httparty logger webdriver pry
require "selenium-webdriver"
require "chromedriver-helper"
require "json"
require "date"
require "pry"
require "httparty"
require "logger"

# https://chromedriver.storage.googleapis.com/index.html
Chromedriver.set_version "97.0.4692.71"

@options = Selenium::WebDriver::Chrome::Options.new(
  options: {
    "excludeSwitches": ["enable-automation"],
    "detach": true
  }
)
@options.add_argument("--no-sandbox")
@options.add_argument("--window-size=1920,1200")
@options.add_argument("--start-maximized")
@options.add_argument("--headless")
@options.add_argument('--disable-blink-features=AutomationControlled')
@options.add_argument("--blink-settings=imagesEnabled=false")
@options.add_argument("--disable-dev-shm-usage")
@options.add_argument("--disable-gpu")
@options.add_argument("disable-infobars")
@options.add_argument('--disable-application-cache')
@options.add_argument('--disable-notifications')

@log = Logger.new("logs/log_#{Time.now.to_i}.txt")
@log.level = Logger::INFO

# @host = "https://fb-crawl-order.herokuapp.com"
# @host = "http://localhost:3000"
@host = "http://103.98.148.95"
@new_crawl = false


# driver = Selenium::WebDriver.for :chrome, @options: @options

def start driver, account, pwd, group_ids
  if File.exist?("cookies/#{account.split("@").first}.json")
    driver.navigate.to "https://www.facebook.com/"
    sleep 5

    cookies = JSON.parse(File.read("cookies/#{account.split("@").first}.json")).map{|i| i.transform_keys(&:to_sym)}
    cookies.each do |cookie|
      cookie[:expires] = Time.now.to_i + 90*86400
      driver.manage.add_cookie(cookie)
    end
    sleep 2
  else
    login(driver, account, pwd)
  end

  driver.navigate.to "https://www.facebook.com/"
  sleep 5

  urls = group_ids.map do |group_id|
    "https://m.facebook.com/groups/#{group_id}?sorting_setting=CHRONOLOGICAL"
  end

  open_chrome_tab(driver, urls)
  send_account_running(account)

  loop do
    sleep rand(3..5)
    break if @new_crawl
    urls.each_with_index do |url, i|
      @log.info "Account: #{account} | Browser #{i + 1} | Thread_ID: #{Process.pid} | #{Time.now.to_i}"
      driver.switch_to.window(driver.window_handles[i])
      driver.navigate.refresh
      sleep 5
      if driver.current_url.include?("checkpoint")
        File.delete("cookies/#{account.split("@").first}.json") if File.exist?("cookies/#{account.split("@").first}.json")
        sleep 2
        send_account_block(account)
        sleep 2
        @new_crawl = true
      else
        crawl_data(driver, group_ids[i], account)
      end
    end
  end
rescue => e
  @log.error e
ensure
  @log.info "close chromedriver"
  driver.quit
  if @new_crawl
    @log.info "close chromedriver"
    @new_crawl = false
    main()
  end
end

def open_chrome_tab driver, urls
  driver.navigate.to urls.first

  urls[1..-1].each do |url|
    driver.execute_script("window.open();")
    sleep 2
    driver.switch_to.window(driver.window_handles.last)
    sleep 2
    driver.navigate.to url
    sleep 3
  end

  driver.switch_to.window(driver.window_handles.first)
end

def crawl_data driver, group_id, account
  list_story = driver.find_elements(:class, "story_body_container").first(10)
  posts = list_story.map do |story|
    text = story.find_elements(:tag_name, "p")
    text = story.find_elements(:tag_name, "span") if text.empty?
    if !/09|03|07|08|05/.match(text.last.text).nil?
      fb_user_post_id = story.find_element(:tag_name, "header").find_elements(:tag_name, "div").map{|i| i.attribute("data-sigil")}.compact.select{|i| i&.include?("feed_story_ring")}.first.gsub!("feed_story_ring", "")
      post_id = story.find_elements(:tag_name, "a").select{|i| i.attribute('href')&.include?("permalink")}.first.attribute('href').split("/")[6]
      {
        username: story.find_element(:tag_name, "strong").text,
        content: text.last.text,
        post_id: "#{group_id}/#{post_id}",
        fb_user_post_id: fb_user_post_id
      }
    else
      nil
    end
  end.compact
  @log.info posts.to_s

  post_data(posts, group_id, account)
end

def post_data posts, group_id, account_crawl
  HTTParty.post(
    "#{@host}/api/v1/posts",
    body: { datas: posts, group_id: group_id, account_crawl: account_crawl}.to_json,
    headers: { "Content-Type" => "application/json", "Authorization" => "bearer 123456789009876543211"}
  )
end

def send_account_block account
  HTTParty.post(
    "#{@host}/api/v1/accounts/account_block",
    body: { account: account }.to_json,
    headers: { "Content-Type" => "application/json", "Authorization" => "bearer 123456789009876543211"}
  )
  @log.error "Block account #{account}"
end

def send_account_running account
  HTTParty.post(
    "#{@host}/api/v1/accounts/account_run",
    body: { account: account }.to_json,
    headers: { "Content-Type" => "application/json", "Authorization" => "bearer 123456789009876543211"}
  )
  @log.info "Account #{account} Running"
end

def login driver, account, pwd
  driver.navigate.to "https://www.facebook.com/"
  sleep 5
  driver.find_element(:id, 'email').send_keys(account)
  sleep 3
  driver.find_element(:id, 'pass').send_keys(pwd)
  sleep 3
  driver.action.send_keys(:enter).perform
  sleep 10

  cookie = driver.manage.all_cookies
  File.open("cookies/#{account.split("@").first}.json","w") { |f| f.write(cookie.to_json) }
  sleep 5
end

def main
  sleep 5
  x = HTTParty.get(
    "#{@host}/api/v1/accounts/list",
    headers: { "Content-Type" => "application/json", "Authorization" => "bearer 123456789009876543211"}
  )

  datas = []
  JSON.parse(x.body)["datas"].each do |data|
    datas << {
      username: data[1]["username"],
      password: data[1]["pwd"],
      groups: data[1]["groups"].map{ |i| i["group_url"] }
    }
  end
  if datas.count.zero?
    @log.info "#{Time.now.to_i} No data runed"
    return
  end

  datas.each_with_index do |data, i|
    Process.fork do
      @log.info "open chromedriver with account #{data[:username]}"
      driver = Selenium::WebDriver.for :chrome, options: @options
      start(driver, data[:username], data[:password], data[:groups])
    end
  end
end


main()
# pkill chrome
