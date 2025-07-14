require 'net/http'
require 'uri'
require 'json'

class Api::V1::ConverterController < ApplicationController
  UNIT_CATEGORIES = {
    "area" => ["sqft", "m2"],
    "volume" => ["liters", "gallons"],
    "temperature" => ["c", "f"],
    "speed" => ["kmh", "mph"]
  }.freeze

  def unit_categories
    log_usage("unit_cartegories_list")
    render json: { categories: UNIT_CATEGORIES }
  end

  @@usage_logs = []

  def log_usage(endpoint)
    @@usage_logs << {
      endpoint: endpoint,
      ip: request.remote_ip,
      time: Time.current
    }
  end

  def usage_log
    render json: { logs: @@usage_logs }
  end

  def convert
    log_usage("currency_convert")

    amount = params[:amount].to_f
    from = params[:from]&.upcase
    to = params[:to]&.upcase

    return render json: { error: 'Missing or invalid parameters' }, status: :bad_request unless amount.positive? && from && to

    converted_amount = convert_currency(amount, from, to)

    if converted_amount
      render json: {
        amount: amount,
        from: from,
        to: to,
        converted: converted_amount.round(4)
      }
    else
      render json: { error: 'Conversion failed or unsupported currency pair' }, status: :unprocessable_entity
    end
  end

  def currencies
    log_usage("currency_list")

    api_key = ENV['EXCHANGE_RATE_API_KEY']
    url = URI("https://v6.exchangerate-api.com/v6/#{api_key}/codes")

    begin
      response = Net::HTTP.get(url)
      data = JSON.parse(response)

      if data['result'] == 'success'
        render json: {
          base_code: data['base_code'],
          supported_codes: data['supported_codes'] # Array of [currency_code, currency_name]
        }
      else
        render json: { error: 'Failed to fetch supported currencies' }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error("Currency list error: #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  def unit_convert
    log_usage("unit_convert")

    amount = params[:amount].to_f
    from = params[:from]&.downcase
    to = params[:to]&.downcase
  
    return render json: { error: 'Missing or invalid parameters' }, status: :bad_request unless amount.positive? && from && to
  
    all_supported_units = UNIT_CATEGORIES.values.flatten
    unless all_supported_units.include?(from) && all_supported_units.include?(to)
      return render json: { error: 'Unsupported unit' }, status: :unprocessable_entity
    end

    conversions = {
      "sqft" => { "m2" => 0.092903 },
      "m2" => { "sqft" => 10.7639 },
      "liters" => { "gallons" => 0.264172 },
      "gallons" => { "liters" => 3.78541 },
      "kmh" => { "mph" => 0.621371 },
      "mph" => { "kmh" => 1.60934 },
      "c" => { "f" => ->(c) { c * 9.0 / 5 + 32 } },
      "f" => { "c" => ->(f) { (f - 32) * 5.0 / 9 } }
    }
  
    rule = conversions[from]&.[](to)
  
    if rule
      result = rule.is_a?(Proc) ? rule.call(amount) : amount * rule
      render json: {
        amount: amount,
        from: from,
        to: to,
        converted: result.round(4)
      }
    else
      render json: { error: 'Unsupported unit conversion' }, status: :unprocessable_entity
    end
  end

  private

  def convert_currency(amount, from, to)
    api_key = ENV['EXCHANGE_RATE_API_KEY']
    url = URI("https://v6.exchangerate-api.com/v6/#{api_key}/latest/#{from}")

    begin
      response = Net::HTTP.get(url)
      data = JSON.parse(response)

      if data['result'] == 'success'
        rate = data['conversion_rates'][to]
        return amount * rate if rate
      end
    rescue => e
      Rails.logger.error("Currency conversion error: #{e.message}")
    end

    nil
  end
end
