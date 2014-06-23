require 'rubygems'
require 'sinatra'

disable :show_exceptions
disable :raise_errors

set :sessions, true

NDECKS = 1 #number of decks in the game

START_AMT =500 #The amount of money that the player starts with

WIN_VALUE = 21 #The object is to get a hand worth this many points

STAY_VALUE = 17 #Dealer stays at this value

SUITS = ["hearts","spades","diamonds","clubs"]

RANKS = ["2", "3", "4", "5", "6", "7", "8", 
        "9", "10", "jack", "queen", "king", "ace"]


VALID_STATUSES = [ 'dealer_won','player_won', 'push',
                 'dealing_to_player', 'dealing_to_dealer']

VALID_MESSAGE_CLASSES = [nil,'alert','info','error','success']

STATUS_MESSAGES = { dealer_won: "Dealer Won!", player_won: "Player Won!", 
                 deal_to_player: "Dealing to player.", push: "Push."}

# These strings are used when printing hands
PLAYERS = {'player_cards' => "Player ", 'dealer_cards' => "Dealer "}

#translation from face values to hard point values
POINTS = [2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10, 1]
RANK_TO_POINTS = Hash[ RANKS.zip(POINTS) ]


#Data structures

#Cards are represented by hashes of form {'rank'=>string,'suit'=>string}                                  

#session hash keys and corresponding instance variables
#session[KEY] to access

#KEY            |INSTANCE VARIABLE  | CONTENTS
#-------------- |-------------------|-------------------------------
#'player_cards'  |                   | an array of card hashes
#-------------- |-------------------|-------------------------------
#'dealer_cards   |                   | an array of card hashes
#-------------- |-------------------|------------------------------- 
#'game_cards'   |                   | an array holding the unplayed cards
#-------------- |-------------------|-------------------------------
#'discard'      |                   | an array of cards corresponding to the discard pile
#-------------- |-------------------|-------------------------------
#'status'       | @status           | a string to represent the status of gameplay.
#               |                   | Possible values:
#               |                   | 'player_won', 'dealer_won', 'dealing_to_player',
#               |                   | 'dealing_to_dealer'
#-------------- |-------------------|------------------------------------------------------          
#'message'      | @message          | a string with a message for the user           
#-------------- |-------------------|---------------------------------------------------
#'message_class'| @message_class    | Possible values 'alert, 'success', 'info', 'error'
#---------------|----------------------------------------------------------------------
#'bet_amount'   | @bet_amount       | an integer describing the size of the bet in $.   
#---------------|------------------ |---------------------------------------------------
# 'balance'     | @balance          | an integer. the player's balance in $. 
#---------------|-----------------------------------------------------------------------
#'player_stayed'

#@player_images, @dealer_images   instance variables. arrays of strings containing
#                                 paths to card pictures.                                   
#@player_stayed

helpers do

 #Reads the contents of the session cookie and saves it to instance variables
  def read_session

    @message = session['message']

    if !VALID_MESSAGE_CLASSES.include?(session['message_class'])
      raise "Unknown message class" 
    end
    @message_class = session['message_class']

    if !VALID_STATUSES.include?(session['status'])
      raise "Unknown status"
    end
    @status = session['status']

    @name = session['name']
    @balance = session['balance']
    @bet_amount = session['bet_amount']
    @player_stayed? = session['player_stayed']
  end

  #Clears the message buffer
  def clear_message
    session['message'] = nil
    session['message_class'] = 'alert'
  end

end


  #Creates and returns a fresh game state object
  def create_game

    session['dealer_cards'] = []
    session['player_cards'] = []
    
    session['discard'] = [] 
    session['game_cards'] = []
  
    session['status'] = 'dealing_to_player'
    session['message'] = ""

    #Give the player her starting money
    session['balance'] = START_AMT

    #Generate an array of {'suit'=>'string','rank'=>'string'} hashes
    #each hash corresponds to a card in the deck
    deck = RANKS.product(SUITS).map do |rank, suit|
      Hash[ ['rank','suit'].zip([rank,suit]) ]
    end
    
    #Add NDECKS to the game cards
    NDECKS.times do 
      session['game_cards'].concat( deck )
    end

    #Shuffle the game cards
    session['game_cards'].shuffle!

  end

  #Methods that move cards around

  #Deal a hand
  def deal_hand()

    session['player_stood?'] = false

    #Discard dealer's old hand
    if ! session['dealer_cards'].empty?
      session['discard'] = session['discard'] | session['dealer_cards']
      session['dealer_cards'] = []
    end


    #Discard player's old hand
    if !session['player_cards'].empty?
      session['discard'] = session['discard'] | session['player_cards']
      session['player_cards'] = []
    end


    #Deal the cards
    2.times do
      deal_card('player_cards')
      deal_card('dealer_cards')
    end
 
    p session['dealer_cards']
    p session['player_cards']

  end

  def deal_card(hand)
  #game_cards and hand are arrays of hashes of form {rank: "string", suit: "string"}
  #hand is an array containing the player's cards.  It can be empty
  #game_cards is an array of all the cards in the deck that haven't been dealt
  #Method moves a card from game_card to hand

    #Check for an empty deck and reshuffle if necessary
    if (session['game_cards'].length == 0)

      session['game_cards'] = session['discard']
      session['game_cards'].shuffle!
      session['discard'] =  []
      session['message'].concat("Shuffled deck.")

    end

    session[hand] << session['game_cards'].pop 

  end

  # #Returns an array of strings. Each string is the path to an image of a card
  def show_hand(hand)
  #hand is an array of hashes of form {'rank' =>string, 'suit' => string}  
 
    images = session[hand].map do |card|
      "/images/cards/#{card['suit']}_#{card['rank']}.jpg"     
    end

    #Hide the player's first card if it's the dealers turn
    if(session['status'] == 'dealing_to_player' && hand=='dealer_cards')
      images[0] = "/images/cards/cover.jpg"
    end

    return images

  end

  #Methods that count cards

  #A method that checks if the specified hand is a blackjack
  def blackjack?(hand)
  # hand == 'dealer_cards' or hand == 'player_cards'
 
    return hand_total( hand ) == 21 && session[hand].length == 2
    
  end

  #a method that checks if the specify hand busted
  def bust?(hand)
  # hand == :dealer_hand or hand == :player_hand 

    return hand_total( hand ) > 21

  end

  #A method to decide the status of the game after an action
  def decide_status

    case session['status']

      when 'dealing_to_player'

        #Both player and dealer hit blackjack
        if blackjack?('player_cards') && blackjack?('dealer_cards')
          session['status'] = 'push'
          session['message'] = "Both #{session['name']} and dealer hit blackjack. Push."
          session['message_class'] = 'info'
        end

        #Player blackjack
        if blackjack?('player_cards')
          session['status']='player_won'
          session['message'] = "session['name'] hit blackjack. #{session[name]} wins!"
          session['message_class'] = 'sucess'
        end

        #Dealer blackjack
        if blackjack?('dealer_cards')
          session['status'] = 'dealer_won'
          session['message'] = "Dealer hit blackjack. Dealer wins!"
          session['message_class'] = 'error'
        end

        #Player bust  
        if bust?('player_cards')
          session['status'] = 'dealer_won'
          session['message'] = \
          "Dealer busts with #{hand_total(player_cards)}. Dealer wins!"
          session['message_class'] = 'error'    
        end
        
        #Player hit 21, it's the dealer's turn now
        if hand_total('player_cards') == 21
          session['status'] == 'dealing_to_dealer'
        end

      when 'dealing_to_dealer'

        #Dealer bust
        if bust?('dealer_cards')
          session['status'] = 'player_won'
          session['message']= \
             "Dealer busts with a #{hand_total('dealer_hand')}. Player wins!"
          session['message_class'] = 'success'
        end

    
        #The hand is over.  Tally and decide winner  
        if hand_total('dealer_cards') >= STAY_VALUE

          #Player won
          if hand_total('player_cards') > hand_total('dealer_cards')
            sesssion['message'] = \
              "#{session['name']} wins with a #{hand_total('player_cards')}"
            session['message_class'] = 'success'

          #Dealer won
          elsif hand_total('player_cards') < hand_total('dealer_cards')
          
            sesssion['message'] = \
              "Dealer wins with a #{hand_total('player_cards')}"
            session['message_class'] = 'error'
        
          #It's a tie. 
          else
            session['message'] = "Push at #{hand_total('player_cards')}"
          end
        
        end

      else
        raise "Unknown status in decide_status: #{session['status']}"
    end
  end

  #Totals the points for a hand
  def hand_total(hand)
   #hand is an array of hashes, each hash corresponding to a card
   #the hashes are of form {rank: "string", suit: 'char'}

    #A flag to see if the hand contains an ace
    puts "hand =" + hand.to_s
    p "hand_total via blackjack " + session[hand].to_s
    have_ace = ! ( session[hand].select{|card| card['rank'] == "ace"}.empty?  )

    total = 0

    #Look up the point value of each card in the hand
    session[hand].each do |card|
      total += RANK_TO_POINTS[ card['rank']]
    end
  

    #Convert from hard (ace=1) to a soft (ace=11) 
    #score if hand contains an ace
    #and it won't cause the hand to bust
    if (total <= 11 && have_ace) then total += 10 end

    return total

  end

  #Reads the contents of the session cookie and saves it to instance variables
  def read_session

    @message = session['message']

    if !VALID_MESSAGE_CLASSES.include?(session['message_class'])
      raise "Unknown message class" 
    end
    @message_class = session['message_class']

    if !VALID_STATUSES.include?(session['status'])
      raise "Unknown status"
    end
    @status = session['status']

    @name = session['name']
    @balance = session['balance']
    @bet_amount = session['bet_amount']
    @player_stayed = session['player_stayed']
  end

  #Clears the message buffer
  def clear_message
    session['message'] = nil
    session['message_class'] = 'alert'
  end

end

#The root path
get '/' do

   #Read user
   if session['name'] == nil
     redirect '/get_name'      
   else
     redirect  '/game'
   end
end


 #Serve the username form
 get '/get_name' do  
   erb :get_name
 end

 #Read username input
 post '/get_name' do
   session['name'] = params['name']
   redirect '/new_game'
 end

#Request a bet amount
get '/bet' do

   read_session
   erb :bet

 end

# Read the user's bet
post '/bet' do

  #Check for invalid characters in input
  if !(params['bet_amount']  =~/^0*[1-9]\d*$/)     

    session['message'] = "Must enter a bet"
    session['message_class'] = 'error'
    redirect '/bet'

  end

  #Save the user's input to a temp variable
  bet_amount = params['bet_amount'].to_i

  #Check for an out of range number
  if bet_amount > session['balance']
    session['message_class'] = 'error'
    session['message'] = "Bet cannot be greater than what you have ($#{session['balance']})."
    redirect '/bet'
  end

  #Save the input and advance gameplay
  session['bet_amount'] = bet_amount
  session['status'] = 'dealing_to_player'
  redirect '/new_hand'

end

post '/play_again' do
  
  if params['play_again'] == true
    redirect '/bet'
  else
    redirect '/goodbye'
  end

end

 get '/new_hand' do
     deal_hand
     decide_status
     redirect '/game'
end

 post '/player/stay' do

   session['player_stood?'] = true
   status = 'dealing_to_dealer'
  
 end

#Direct player to appropriate goodbye screen
get '/goodbye' do

  read_session

  case session['balance']

    when session['balance'] > 0
       erb :winner_bye
    else
       erb :loser_bye   
 end

end

#Display the main game screen
 get '/game' do

   read_session

   #Sanity checks

   if session['dealer_cards'].empty?
     raise "No cards dealt to dealer"
   end

  if session['player_cards'].empty?
    raise "No cards dealt to player"
  end

  if (!session['bet_amount'].is_a?(Fixnum)  ||
       session['bet_amount'] <= 0)
     raise "Illegal bet"
  end

#   #Convert cards to image files
   @dealer_images=show_hand('dealer_cards')
   @player_images=show_hand('player_cards')

#   @show_new_hand_buttons = false
#   @show_hit_stay_buttons = false

case @status
  
    when 'dealer_won'  
    
    @alert_class = "alert-error"
    @show_new_hand_buttons = true

    when 'player_won'  
    @alert_class = "alert-info" #light blue 
    @show_new_hand_buttons = true

    when :push  
      possible_actions = [:new_hand, :new_game, :quit]
      action = request_user_action(game, possible_actions)

    when :deal_to_player 

      possible_actions = [:hit,:stay,:new_game,:quit]
      action = request_user_action(game, possible_actions)

    #The next action should be to play out the dealer's hand
    when :deal_to_dealer
      action = [:play_dealer]
    
    #The next action should be to tally up the scores
    when :tally      
      action = [:tally]    

    else
      # p game[:status]
      # raise "Main game loop: Illegal status #{game[:status]}"
  end
# # ['player_won','player_lost'].include?(session['status'])
# # @show_hit_stay_buttons = ['plsyer)']

 erb :game

 end

#Debugging routes

get '/debug/set_status' do
  session['status'] = params['status']
  puts  session['status']
end

get '/debug/set_message' do 
  session['message'] = params['message']
  puts session['message']
end

get '/new_game' do
  create_game
  redirect '/bet'
end

get '/clear_message' do
  clear_message
end

get '/dealer_blackjack' do
  session['dealer_cards'] = []
  session['dealer_cards'] << {'rank' => 'ace', 'suit' => 'spades'}
  session['dealer_cards'] << {'rank' => 'queen', 'suit' => 'spades'}
  decide_status
  redirect '/game'

end

# if session[:status] == :player_won || session[:status] == :dealer_won
#   @play_again_flag = true
# end  
# erb :game
  # case status
  #   when :dealer_won, :player_won
  #     buttons
  # erb :hit_view
#end

# post '/i_hit' do
#   "You hit"
# end
=begin

 / => form to put in name, which redirects to form to take bet
 => redirects you to cards
 cards has hit and stay buttons, which have associate post actions
           


 bet  => put in bet
      => redirect to view cards

      =
 view_cards
  says


=end
#rescue Exception => e
  
#end

# ef do_action(game, action)

#   case action

#     #User asked for a new game
#     when :new_game

#         game = create_game()
#         game[:message] = "Created new game"
#         game[:status] = :deal_to_player
#         deal_hand(game)

#     #User asked for a new hand    
#     when :new_hand
     
#       deal_hand(game) 
#       game[:status] = :deal_to_player

#       #Check for player blackjack  
#       if blackjack?(game, :player_hand)
#         game[:status] = :deal_to_dealer
#       end

#     #User asked to hig  
#     when :hit
      
#       deal_card(game, :player_hand)

#       #Check for a player bust
#       if bust?( game, :player_hand )
#         game[:status] = :dealer_won
#       end
      
#       #Check for player 21  
#       if hand_total(game[ :player_hand]) == 21
#         game[:status] = :deal_to_dealer
#       end

#     #User asked to stay
#     when :stay
#       game[:status] = :deal_to_dealer

#     #Main script asked to play out the dealer's hand
#     when :play_dealer

#       play_dealer(game)
#       game[:status] = :tally

#      #Check for a dealer bust
#       if bust?( game, :dealer_hand )
#         game[:status] = :player_won
#       end

#     #Main script asked to count the cards and see who wom  
#     when :tally
     
#       player_diff = 21 -  hand_total( game[:player_hand] ) 
#       dealer_diff = 21 - hand_total( game[:dealer_hand] )

#       #Both player and dealer have blackjacks
#       if blackjack?(game, :player_hand ) and blackjack?(game, :dealer_hand)
#         game[:status]=:push

#       #Dealer has a blackjack
#       elsif blackjack?(game, :dealer_hand)  
#         game[:status] = :dealer_won
        
#       #Player has a blackjack  
#       elsif blackjack?(game, :player_hand)  
#         game[:status] = :dealer_won 
 
#       #Check for winner or push
#       else 

#         if (player_diff > dealer_diff)
#           game[:status] = :dealer_won
#         elsif (player_diff < dealer_diff)
#           game[:status] = :player_won
#         else
#           game[:status] = :push
#         end

#       end

#     else raise "Unknown action requested"
    
#   end

#   return game

# end
