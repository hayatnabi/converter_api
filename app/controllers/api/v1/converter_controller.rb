require 'net/http'
require 'uri'
require 'json'

class Api::V1::ConverterController < ApplicationController
  def convert
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
