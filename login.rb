# gem install selenium-webdriver chromedriver-helper
require "selenium-webdriver"
require "chromedriver-helper"
require "pry"

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
#options.add_argument("--headless")
options.add_argument('--disable-blink-features=AutomationControlled')
# options.add_argument("--blink-settings=imagesEnabled=false")
options.add_argument("--disable-dev-shm-usage")
options.add_argument("--disable-gpu")
options.add_argument("disable-infobars")
options.add_argument('--disable-application-cache')
options.add_argument('--disable-notifications')

driver = Selenium::WebDriver.for :chrome, options: options
driver.navigate.to "https://www.facebook.com/"
sleep 5

driver.find_element(:id, 'email').send_keys("tuanpahumg@gmail.com")
sleep 3
driver.find_element(:id, 'pass').send_keys("123!@#QweQ")
sleep 3
driver.action.send_keys(:enter).perform
sleep 10

cookie = driver.manage.all_cookies
File.open("cookies.json","w") { |f| f.write(cookie.to_json) }

sleep 5

driver.quit
