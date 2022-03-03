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
@options.add_argument("--blink-settings=imagesEnabled=false")
@options.add_argument('--disable-blink-features=AutomationControlled')
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
    "https://facebook.com/groups/#{group_id}?sorting_setting=CHRONOLOGICAL"
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
  driver.save_screenshot("image_logs/dead_#{Time.now.to_i}.jpg")
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
  driver.execute_script("window.scrollTo(0, document.body.scrollHeight)")
  sleep 3
  driver.execute_script("window.scrollTo(0, document.body.scrollHeight)")
  sleep 3

  list_story = driver.find_elements(:xpath, '//div[@role="feed"]/div').first(10)[1..-1]
  posts = list_story.map do |story|
    # text = story.find_elements(:xpath, './/div/div/div/div/div/div/div/div/div/div/div[2]/div/div[1]')[3].text
    text = story.text
    if !/09|03|07|08|05/.match(text).nil?
      text = text[text.index("\n  ·\n")...text.index("\nThích\n")]&.gsub("\n  ·\n", "")&.gsub("Bình luận", "")&.gsub("Chia sẻ", "")&.gsub(/[0-9] bình luận/, "")&.gsub("Đang hoạt động", "")&.gsub("nViết bình luận công khai…", "")
      driver.action.move_to(story.find_elements(:tag_name, "a")[3]).perform
      sleep 0.5
      link_user = story.find_elements(:tag_name, "a").select{|i| i.attribute("href").include?("user/")}.first.attribute("href")
      fb_user_post_id = link_user[link_user.index('user/')+5...link_user.index('/?')]
      link_post = story.find_elements(:tag_name, "a").select{|i| i.attribute("href").include?("posts")}.count
      link_post = story.find_elements(:tag_name, "a").select{|i| i.attribute("href").include?("posts/")}.first.attribute("href")
      post_id = link_post[link_post.index('posts/')+6...link_post.index('/?')]
      username = story.find_element(:tag_name, 'h2').text

      {
        username: story.find_element(:tag_name, "strong").text,
        content: text,
        post_id: "#{group_id}/#{post_id}",
        fb_user_post_id: fb_user_post_id
      }
    else
      nil
    end
  end.compact
  @log.info posts.to_s

  driver.save_screenshot("image_logs/#{account.split("@").first}_#{group_id}.jpg") if posts.empty?
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
  # driver = Selenium::WebDriver.for :chrome, options: @options
  # start(driver, "danchoidaosip6@gmail.com", "Tt29042010@", ["220028958474708"])
  # return
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
    username = data[:username]
    password = data[:password]
    groups = data[:groups]
    groups.each_slice(8) do |groupss|
      sleep 10
      Process.fork do
        @log.info "open chromedriver with account #{username} groups: #{groupss.join(", ")}"
        driver = Selenium::WebDriver.for :chrome, options: @options
        start(driver, username, password, groupss)
      end
    end
  end
end


main()
# pkill chrome
