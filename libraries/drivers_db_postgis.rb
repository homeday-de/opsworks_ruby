# frozen_string_literal: true
module Drivers
  module Db
    class Postgis < Base
      adapter :postgis
      allowed_engines :postgis
    end
  end
end
