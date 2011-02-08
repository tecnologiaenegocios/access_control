# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_access_control_app_session',
  :secret      => 'c01bfd8f0ac60263cff9381d11d42f4c7f3a8572ad2b729388750ac7132969b03fd7ff93b863d05264196f701887435f5caae89b9f7bf0ed777a7d5e06c4ede9'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
