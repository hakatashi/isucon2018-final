require 'json'
require 'time'

require 'sinatra/base'

require_relative './models.rb'
require_relative './errors.rb'

module Isucoin
  class Web < Sinatra::Base
    configure :development do
      require 'sinatra/reloader'
      register Sinatra::Reloader
    end

    set :public_folder, ENV.fetch('ISU_PUBLIC_DIR', File.join(__dir__, '..', 'public'))
    set :sessions, key: 'isucoin_session', expire_after: 3600
    set :session_secret, 'tonymoris'
    # ISUCON用初期データの基準時間です
    # この時間以降のデータはinitializeで削除されます
    set :base_time, Time.new(2018, 10, 16, 10, 0, 0)

    helpers do
      include Isucoin::Models

      def user_by_request
        if session[:user_id]
          user = get_user_by_id(session[:user_id])
          if user
            return user
          end
        end
      end
    end

    set :login_required, ->(_value) do
      condition do
        unless session[:user_id]
          halt 401, {code: 401, err: 'Not authenticated'}.to_json
        end
      end
    end

    before do
      content_type :json

      if session[:user_id]
        unless get_user_by_id(session[:user_id])
          session[:user_id] = nil
          halt 404, {code: 404, err: 'セッションが切断されました'}.to_json
        end
      end
    end

    get '/' do
      content_type :html
      File.read(File.join(__dir__, '..', 'public', 'index.html'))
    end

    post '/initialize' do
      [
        "DELETE FROM orders WHERE created_at >= '2018-10-16 10:00:00'",
        "DELETE FROM trade WHERE created_at >= '2018-10-16 10:00:00'",
        "DELETE FROM user WHERE created_at >= '2018-10-16 10:00:00'",
        "DELETE FROM candle_by_sec WHERE `date` >= '2018-10-16 10:00:00'",
        "DELETE FROM candle_by_min WHERE `date` >= '2018-10-16 10:00:00'",
        "DELETE FROM candle_by_hour WHERE `date` >= '2018-10-16 10:00:00'",
      ].each do |q|
        db.query(q)
      end

      host = ENV.fetch('ISU_DB_HOST', '127.0.0.1')
      port = ENV.fetch('ISU_DB_PORT', '3306')
      user = ENV.fetch('ISU_DB_USER', 'root')
      passwd = ENV['ISU_DB_PASSWORD']
      dbname = ENV.fetch('ISU_DB_NAME', 'isucoin')
      `mysql -u#{user} -p#{passwd} --host #{host} --port #{port} #{dbname} < /candle/candle_by_s.sql`
      `mysql -u#{user} -p#{passwd} --host #{host} --port #{port} #{dbname} < /candle/candle_by_m.sql`
      `mysql -u#{user} -p#{passwd} --host #{host} --port #{port} #{dbname} < /candle/candle_by_h.sql`

      %i(
        bank_endpoint
        bank_appid
        log_endpoint
        log_appid
      ).each do |k|
        set_setting(k, params[k])
      end

      '{}'
    end

    post '/signup' do
      unless params[:name] && params[:bank_id] && params[:password]
        halt 400, {code: 400, err: "all parameters are required"}.to_json
      end

      response = db.xquery('SELECT count FROM signup_failure WHERE bank_id = ?', params[:bank_id])
      failure_count = 0
      if response.count > 0
        failure_count = response.first.fetch('count')
      end

      if failure_count >= 8
        e = TooManyFailures.new
        halt 403, {code: 403, err: e.message}.to_json
      end

      begin
        user_signup(params[:name], params[:bank_id], params[:password])
      rescue BankUserNotFound => e
        db.xquery('INSERT INTO signup_failure (bank_id, `count`) VALUES (?, 1) ON DUPLICATE KEY UPDATE `count` = `count` + 1', params[:bank_id])
        halt 404, {code: 404, err: e.message}.to_json
      rescue BankUserConflict => e
        db.xquery('INSERT INTO signup_failure (bank_id, `count`) VALUES (?, 1) ON DUPLICATE KEY UPDATE `count` = `count` + 1', params[:bank_id])
        halt 409, {code: 409, err: e.message}.to_json
      end

      db.xquery('UPDATE IGNORE signup_failure SET `count` = 0 WHERE bank_id = ?', params[:bank_id])

      '{}'
    end

    post '/signin' do
      unless params[:bank_id] && params[:password]
        halt 400, {code: 400, err: "all parameters are required"}.to_json
      end

      begin
        user = user_login(params[:bank_id], params[:password])
        session[:user_id] = user.fetch('id')
      rescue UserNotFound => e
        # TODO: 失敗が多いときに403を返すBanの仕様に対応
        # 気にしない!!!!!!!!
        halt 404, {code: 404, err: e.message}.to_json
      end

      {
        id: user.fetch('id'),
        name: user.fetch('name'),
      }.to_json
    end

    post '/signout' do
      session[:user_id] = nil
      '{}'
    end

    get '/info' do
      res = {}

      last_trade_id = params[:cursor] && !params[:cursor].empty? ? params[:cursor].to_i : nil
      last_trade = last_trade_id && last_trade_id > 0 ? get_trade_by_id(last_trade_id) : nil
      lt = last_trade ? last_trade.fetch('created_at') : Time.at(0)

      latest_trade = get_latest_trade()
      res[:cursor] = latest_trade&.fetch('id')

      user = user_by_request()
      if user
        orders = get_orders_by_user_id_and_last_trade_id(user.fetch('id'), last_trade_id).to_a
        orders.each do |order|
          fetch_order_relation(order)
          order[:user] = {id: order.dig(:user, 'id'), name: order.dig(:user, 'name')} if order[:user]
          order[:trade]['created_at'] = order.dig(:trade, 'created_at').xmlschema if order.dig(:trade, 'created_at')
          order['created_at'] = order['created_at'].xmlschema if order['created_at']
          order['closed_at'] = order['closed_at'].xmlschema if order['closed_at']
        end
        res[:traded_orders] = orders
      end

      by_sec_time = settings.base_time - 300
      if by_sec_time < lt
        by_sec_time = Time.new(lt.year, lt.month, lt.day, lt.hour, lt.min, lt.sec)
      end
      #res[:chart_by_sec] = get_candlestick_data(by_sec_time, "%Y-%m-%d %H:%i:%s")
      res[:chart_by_sec] = get_candlestick_data_sec(by_sec_time)

      by_min_time = settings.base_time - (300 * 60)
      if by_min_time < lt
        by_min_time = Time.new(lt.year, lt.month, lt.day, lt.hour, lt.min, 0)
      end
      #res[:chart_by_min] = get_candlestick_data(by_min_time, "%Y-%m-%d %H:%i:00")
      res[:chart_by_min] = get_candlestick_data_min(by_min_time)

      by_hour_time = settings.base_time - (48 * 3600)
      if by_hour_time < lt
        by_hour_time = Time.new(lt.year, lt.month, lt.day, lt.hour, 0, 0)
      end
      #res[:chart_by_hour] = get_candlestick_data(by_hour_time, "%Y-%m-%d %H:00:00")
      res[:chart_by_hour] = get_candlestick_data_hour(by_hour_time)

      lowest_sell_order = get_lowest_sell_order()
      res[:lowest_sell_price] = lowest_sell_order.fetch('price') if lowest_sell_order
      highest_buy_order = get_highest_buy_order()
      res[:highest_buy_price] = highest_buy_order.fetch('price') if highest_buy_order

      # TODO: trueにするとシェアボタンが有効になるが、アクセスが増えてヤバイので一旦falseにしておく
      res[:enable_share] = true

      %i(chart_by_hour chart_by_min chart_by_sec).each do |k|
        res[k].each do |cs|
          cs['time'] = cs.fetch('time').xmlschema
        end
      end
      res.to_json
    end

    post '/orders', login_required: true do
      user = user_by_request()
      amount = params[:amount]&.to_i
      price = params[:price]&.to_i

      begin
        rollback = false
        db.query('BEGIN')
        order = add_order(params[:type], user.fetch('id'), amount, price)
        db.query('COMMIT')
      rescue ParameterInvalid, CreditInsufficient => e
        rollback = true
        halt 400, {code: 400, err: e.message}.to_json
      ensure
        db.query('ROLLBACK') if $! || rollback
      end

      if has_trade_chance_by_order(order.fetch('id'))
        begin
          run_trade()
        rescue => e
          # トレードに失敗してもエラーにはしない
          $stderr.puts "run_trade error: #{e.full_message}"
        end
      end

      {id: order['id']}.to_json
    end

    get '/orders', login_required: true do
      user = user_by_request()
      #orders = get_orders_by_user_id(user.fetch('id')).to_a
      orders = get_orders_by_user_id2(user.fetch('id')).to_a
      orders.each do |order|
        order[:user] = {
          id: order[:user_id], name: order[:user_name]
        } if order[:user_name]
        order[:trade] = {
          id: order[:trade_id],
          amount: order[:trade_amount],
          price: order[:trade_price],
          created_at: order[:trade_created_at]
        } if order[:trade_price]
      end

=begin
      orders.each do |order|
        fetch_order_relation(order)
        order[:user] = {id: order.dig(:user, 'id'), name: order.dig(:user, 'name')} if order[:user]
        order[:trade]['created_at'] = order.dig(:trade, 'created_at').xmlschema if order.dig(:trade, 'created_at')
        order['created_at'] = order['created_at'].xmlschema if order['created_at']
        order['closed_at'] = order['closed_at'].xmlschema if order['closed_at']
      end
=end

      orders.to_json(:except => [:user_name, :trade_amount, :trade_price, :trade_created_at])
    end

    delete '/order/:id', login_required: true do
      user = user_by_request()
      id = params[:id]&.to_i

      begin
        rollback = false
        db.query('BEGIN')
        delete_order(user.fetch('id'), id, 'canceled')
        db.query('COMMIT')
      rescue OrderNotFound, OrderAlreadyClosed => e
        rollback = true
        halt 404, {code: 404, err: e.message}.to_json
      ensure
        db.query('ROLLBACK') if $! || rollback
      end

      {id: id}.to_json
    end
  end
end
