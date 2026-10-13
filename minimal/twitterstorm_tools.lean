import Twitterstorm.Scheduler
import Twitterstorm.Tracker
import Twitterstorm.AccountWorker
import Twitterstorm.Proxy

/-- Twitterstorm tools module. Provides unified tooling for the Twitterstorm project. -/
namespace Twitterstorm.Tools

/-- Common tooling utilities for Twitterstorm. -/
def hello : String := "Twitterstorm Tools"

/-- Twitterstorm scheduler tools. -/
def schedulerTools : List String := [
  "scheduler-merge-task",
  "sync-aristotle",
  "key-loader"
]

/-- Twitterstorm tracker tools. -/
def trackerTools : List String := [
  "tracker-key-loader",
  "tracker-gokujo"
]

/-- Twitterstorm account worker tools. -/
def accountWorkerTools : List String := [
  "account-worker-deployment",
  "relogin-account-browser",
  "relogin-account"
]

/-- Twitterstorm proxy tools. -/
def proxyTools : List String := [
  "proxy-interop",
  "proxy-monitor"
]

/-- All Twitterstorm tools. -/
def allTools : List String := schedulerTools ++ trackerTools ++ accountWorkerTools ++ proxyTools

end Twitterstorm.Tools