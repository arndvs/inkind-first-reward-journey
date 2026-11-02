# Resets the local demo and the RAILS_DEMO warehouse schema. Development only.
# Stop the dev server (bin/dev) first: SQLite files can't be dropped while Puma holds them open.
namespace :demo do
  desc "Reset and seed the local database, re-run sql/10 in Snowflake, clear the CDI watermark (development only)"
  task reset: :environment do
    abort "demo:reset only runs in development" unless Rails.env.development?

    Rake::Task["db:reset"].invoke
    puts Demo::Reset.new.run
  end
end
