# gem install selenium-webdriver chromedriver-helper pry httparty
require "selenium-webdriver"
require "chromedriver-helper"
require "json"
require "date"
require "pry"
require "httparty"

# https://chromedriver.storage.googleapis.com/index.html
Chromedriver.set_version "97.0.4692.71"

options = Selenium::WebDriver::Chrome::Options.new(
  options: {
    "excludeSwitches": ["enable-automation"],
    "detach": true
  }
)
options.add_argument("--no-sandbox")
options.add_argument("--window-size=1920,1200")
options.add_argument("--start-maximized")
options.add_argument("--headless")
options.add_argument('--disable-blink-features=AutomationControlled')
options.add_argument("--blink-settings=imagesEnabled=false")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("--disable-gpu")
options.add_argument("disable-infobars")
options.add_argument('--disable-application-cache')
options.add_argument('--disable-notifications')

puts "open chromedriver"
driver = Selenium::WebDriver.for :chrome, options: options

def main driver
  driver.navigate.to "https://www.facebook.com/"
  sleep 5

  cookies = JSON.parse(File.read("cookies.json")).map{|i| i.transform_keys(&:to_sym)}
  cookies.each do |cookie|
    cookie[:expires] = Time.now.to_i + 90*86400
    driver.manage.add_cookie(cookie)
  end

  sleep 5
  driver.navigate.to "https://www.facebook.com/"
  sleep 5


  loop do
    sleep rand(3..5)
    crawl_data driver, "https://m.facebook.com/groups/710752063666767?sorting_setting=CHRONOLOGICAL"
  end
rescue => e
  puts e
ensure
  puts "close chromedriver"
  driver.quit
end

def crawl_data driver, url
  driver.navigate.to url
  sleep 3
  list_story = driver.find_elements(:class, "story_body_container").first(10)
  list_story_has_phone = list_story.select{|story| !/09|03|07|08|05/.match(story.find_element(:tag_name, "p").text).nil?}
  posts = list_story_has_phone[0...10].map do |post|
    post_id = post.find_elements(:tag_name, "a").select{|i| i.attribute('href').include?("permalink")}.first.attribute('href').split("/")[6]
    {
      username: post.find_element(:tag_name, "strong").text,
      content: post.find_element(:tag_name, "p").text,
      post_id: "710752063666767/#{post_id}"
    }
  end

  puts Time.now.to_i

  HTTParty.post(
    "https://fb-crawl-order.herokuapp.com/api/v1/posts",
    body: { datas: posts }.to_json,
    headers: { "Content-Type" => "application/json", "Authorization" => "bearer 123456789009876543211"}
  )
end

main(driver)
