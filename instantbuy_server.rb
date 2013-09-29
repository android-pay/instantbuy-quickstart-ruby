=begin
/**
 * Copyright 2013 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @version 1.0
 */
=end

require 'sinatra'
require 'json'
require 'jwt'
require_relative 'wallet_constants.rb'

include WalletConstants

before do
  pass if request.get? 
  @input = JSON.parse request.body.read  if (request.body && request.body.size > 0)
end

post "/masked-wallet" do
  _assert_input(['estimatedTotalPrice', 'currencyCode'])  
  now = Time.now.utc.to_i
  mwr = {
    'aud' => 'Google',
    'iat' => now,
    'exp' => now + 3600,
    'iss' => MERCHANT_ID,
    'typ' => 'google/wallet/online/masked/v2/request',
    'request' => {
      'clientId' => CLIENT_ID,
      'merchantName' => MERCHANT_NAME,
      'origin' => ORIGIN,
      'pay' => {
        'estimatedTotalPrice' => _to_dollars(@input['estimatedTotalPrice']).to_s,
        'currencyCode' => @input['currencyCode'].to_s
    },
    'ship' => Hash.new  
    }
  }
  mwr['request']['googleTransactionId'] = @input['googleTransactionId'] if(@input['googleTransactionId'])
  logger.info(mwr)
  JWT.encode(mwr, MERCHANT_SECRET) 
end

put "/masked-wallet" do
  _assert_input(['jwt', 'googleTransactionId'])
  now = Time.now.utc.to_i
  mwr = JWT.decode(@input['jwt'], nil, false)
  mwr['iat'] = now
  mwr['exp'] = now + 3600
  mwr['request']['googleTransactionId'] = @input['googleTransactionId']
  mwr['request']['ship'] = Hash.new
  JWT.encode(mwr, MERCHANT_SECRET)
end


post "/full-wallet" do
  now = Time.now.utc.to_i  
  cart_data = @input['cart']
  total_price = _to_dollars(cart_data['totalPrice']).to_s;
  currency_code = cart_data['currencyCode'];
  line_items = cart_data['lineItems'];
  line_items.each do |item|
    item['totalPrice'] = _to_dollars(item['totalPrice']).to_s  if item['totalPrice']
    item['unitPrice'] = _to_dollars(item['unitPrice']).to_s  if item['unitPrice']
  end

  fwr = {   
    'iat' => now,
    'exp' => now + 3600,
    'typ' => 'google/wallet/online/full/v2/request',
    'aud' => 'Google',
    'iss' => MERCHANT_ID,    
    'request' => {
      'merchantName' => MERCHANT_NAME,
      'googleTransactionId' => @input['googleTransactionId'],
      'origin' => ORIGIN,
      'cart' => {
        'totalPrice' => total_price,
        'currencyCode' => currency_code,
        'lineItems' => line_items  
      }
    }
  }
  logger.info(fwr)
  JWT.encode(fwr, MERCHANT_SECRET)
end



post "/notify-transaction-status" do
  _assert_input(['jwt']) 
  now = Time.now.utc.to_i  
  full_jwt_res = JWT.decode(@input['jwt'], nil, false)
  full_res = full_jwt_res['response']
  nts = {   
    'iat' => now,
    'exp' => now + 3600,
    'typ' => 'google/wallet/online/transactionstatus/v2/request',
    'aud' => 'Google',
    'iss' => MERCHANT_ID,    
    'request' => {
      'merchantName' => MERCHANT_NAME,
      'googleTransactionId' => full_res['googleTransactionId'],
      'status' => 'SUCCESS'
    }
  }
  JWT.encode(nts, MERCHANT_SECRET)
end



get "/" do
  File.read("_index.html")
end


private

def _assert_input(required)
  required.each  do |req|
    unless @input[req]
      halt 400, ('Bad request, expected '+ req +'in the request.')  
    end
  end  
end

def _to_dollars(microdollars)
  sprintf("%.2f", (microdollars.to_f/1000000))
end


