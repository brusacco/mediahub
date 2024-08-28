# frozen_string_literal: true

# app/services/application_service.rb
class ApplicationService
  def self.call(...)
    new(...).call
    # rescue RestClient::ExceptionWithResponse => e
    #  OpenStruct.new({ success?: false, error: e.message })
  end

  def handle_error(error)
    OpenStruct.new({ success?: false, error: error })
  end

  def handle_success(data)
    OpenStruct.new({ success?: true, data: data })
  end
end
