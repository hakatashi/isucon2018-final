# https://re-engines.com/2018/08/13/rails-puma-performance-tuning/
threads 5, 5
workers 3
preload_app!

stdout_redirect "/app/logs/puma.stdout.log", "/app/logs/puma.stderr.log", true
