module Scrappy
  module Errors
    def self.registered app
      app.error do
        "Internal error"
      end

      app.not_found do
        "Resource not found"
      end
    end
  end
end