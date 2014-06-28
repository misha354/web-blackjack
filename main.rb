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

IMAGE_DIR = "/images/cards" #directory containing card images

VALID_STATUSES = [ 'dealer_won','player_won', 'push',
                 'dealing_to_player', 'dealing_to_dealer']

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
#---------------|-------------------|--------------------------------------------------
#'bet_amount'   | @bet_amount       | an integer describing the size of the bet in $.   
#---------------|------------------ |---------------------------------------------------
# 'balance'     | @balance          | an integer. the player's balance in $. 
#---------------|-------------------|---------------------------------------------------
#'player_stayed'| @player_stayed    | a boolean flag set to true if the player stayed
#---------------|-------------------|------------------------------------------------
#'error'        | @error            | an error message string

#@player_images, @dealer_images   instance variables. arrays of strings containing
#                                 paths to card pictures.                                   


helpers do

  #Methods that access and update the contents of the session cookie

 #Reads the contents of the session cookie and saves it to instance variables
  def read_session

    @message = session['message'] #set the message instance variable

    #Validate status
    if !VALID_STATUSES.include?(session['status'])
      raise "Unknown status"
    end

    #Set the color of the message box

    case session['status']

      when 'player_won' 
        @message_class = "success"
      when 'dealer_won'
        @message_class = "error"
      else
        @message_class = "alert"
      end
                    
    @status = session['status'] #set the status instance variable

    #set the remaining instance variables
    @name = session['name']
    @balance = session['balance']
    @bet_amount = session['bet_amount']
    @player_stayed = session['player_stayed']

  end

  #Returns an array of strings. Each string is the path to an image of a card
  def show_hand(hand)
  #hand is a string with valid values 'player_cards' and 'dealer_cards'

    images = session[hand].map do |card|
      "#{IMAGE_DIR}/#{card['suit']}_#{card['rank']}.jpg"     
    end

    #Hide the player's first card if it's the dealers turn
    if(session['status'] == 'dealing_to_player' && hand=='dealer_cards')
      images[0] = "#{IMAGE_DIR}/cover.jpg"
    end

    return images

  end

  #Clears the message buffer
  def clear_message
    session['message'] = nil
    session['message_class'] = 'alert'
  end

  #Clears the status
  def clear_status
    session['status'] = nil
  end

  def append_message(message)
    session['message'] = session['message'].to_s + message
  end

  def record_dealer_win
    session['message_class'] = 'error'
    session['status'] = 'dealer_won'
    session['balance'] -= session['bet_amount']
  end

  def record_player_win
    session['message_class'] = 'success'
    session['status'] = 'player_won'
    session['balance'] += session['bet_amount']
  end

  #Creates a fresh game in the session hash
  def create_game

    #Initialize the the card collections
    session['dealer_cards'] = []
    session['player_cards'] = []
    session['discard'] = [] 
    session['game_cards'] = []
  
    #Inititalize flags and message strings
    session['status'] = 'dealing_to_player'
    session['message'] = nil
 
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

    #Reset the boolean flag that indicates that player stayed in this hand
    session['player_stayed'] = false

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
 
  end

  #Method moves a card from game cards to specified hand
  def deal_card(hand)
  #hand is a string whose valid values are 'player_cards' and 'dealer_cards'

    if !['player_cards','dealer_cards'].include?(hand)
      raise "Unknown hand #{hand}"
    end

    #Check for an empty deck and reshuffle if necessary
    if (session['game_cards'].length == 0)

      session['game_cards'] = session['discard']
      session['game_cards'].shuffle!
      session['discard'] =  []
      append_message("Dealer shuffled the cards.")

    end

    #Move the card
    session[hand] << session['game_cards'].pop 

  end

  #Methods that count cards

  #A method that checks if the specified hand is a blackjack
  def blackjack?(hand)
  # hand == 'dealer_cards' or hand == 'player_cards'
 
    return hand_total( hand ) == 21 && session[hand].length == 2
    
  end

  #a method that checks if the specify hand busted
  def bust?(hand)
  # hand == 'dealer_cards' or hand == 'player_cards' 

    return hand_total( hand ) > 21

  end

   #Totals the points for a hand
  def hand_total(hand)
   #hand is a string with valid values 'dealer_cards' and 'player_cards'

    #A flag to see if the hand contains an ace
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

  #A method to decide the status of the game after an action
  #Sets the message accordingly
  #This method contains all the game logic
  def decide_status

    case session['status']
     
      when 'dealing_to_player'

        #Both player and dealer hit blackjack
        if blackjack?('player_cards') && blackjack?('dealer_cards')
          session['status'] = 'push'
          append_message( "Both #{session['name']} and dealer hit blackjack. Push.")
        
        #Player blackjack
        elsif blackjack?('player_cards')
          append_message  "#{session['name']} hit blackjack."
          record_player_win

        #Dealer blackjack
        elsif blackjack?('dealer_cards')
            append_message  "Dealer hit blackjack. "
            record_dealer_win

        #Player bust  
        elsif bust?('player_cards')
          append_message(
          "#{session['name']} busts with #{hand_total('player_cards')}. ")
          record_dealer_win
        
        #Player hit the winning value, it's the dealer's turn now
        elsif hand_total('player_cards') == WIN_VALUE
          append_message("Player stays at #{WIN_VALUE}. ")
          session['status'] = 'dealing_to_dealer'

        #The player can hit or stay  
        else  
          ;
        end
      
      when 'dealing_to_dealer'

        #Dealer busted
        if bust?('dealer_cards')
          append_message(
            "Dealer busts with #{hand_total('dealer_cards')}. ")
          record_player_win          

#----------------------------------------------------------------------------------------          
        #The dealer is staying  Tally and decide winner  
        elsif hand_total('dealer_cards') >= STAY_VALUE
            
          append_message("Dealer stays at #{hand_total('dealer_cards')}. ")
          
          #Player won
          if hand_total('player_cards') > hand_total('dealer_cards')
            record_player_win

          #Dealer won
          elsif hand_total('player_cards') < hand_total('dealer_cards')
            record_dealer_win 

          #It's a tie. 
          else
            session['message'] = "Push at #{hand_total('player_cards')}. "
            session['status'] = 'push'
          end
#--------------------------------------------------------------------------------------------             
        #The dealer is hitting
        else ;
          
        end #closes if dealer busted
      
      when 'dealer_won', 'player_won', 'push' 
      #Hand is over. Do nothing. 

      else 
      #An unknown status was detected
        raise "Unknown status in decide_status: #{session['status']}"
  
    end #closes case 'session['status]'

  
  end #closes the method

#end of helper methods  
end

#The root path
get '/' do

   #No name set yet 
   if session['name'] == nil
     redirect '/get_name' 
   #No bet set yet       
   elsif session['bet_amount'] == nil
     redirect  '/bet'
   else
    redirect '/game'
   end
end

#Preliminaries

 #Serve the username form
 get '/get_name' do  
   erb :get_name
 end

 #Read username input
 post '/get_name' do
   session['name'] = params['name']
   redirect '/new_game'
 end

#Generate a new game
get '/new_game' do
  create_game
  clear_message
  clear_status
  redirect '/new_hand'
end

#Deal a new hand
get '/new_hand' do
 
  #Player ran out of money  
  if session['balance'] == 0
   redirect '/goodbye'

  #Error! 
  elsif 
    session['balance'] < 0
    raise "Negative balance"
  
  else 
    #Clear status and message and take bet 
    clear_message
    deal_hand     
    clear_status
    redirect '/bet'
  end
end

#Request a bet amount
get '/bet' do
#Uses session['error'] and @error to display error messages

  @name = session['name']
  @message = session['message']
  @balance = session['balance']
  @error = session['error'] 
  session['bet_amount'] = nil
  erb :bet

 end

# Read the user's bet
post '/bet' do

  #Check for invalid characters in input
  if !(params['bet_amount']  =~/^0*[1-9]\d*$/)     

    session['error'] = "Must enter a bet"
    redirect '/bet'

  end

  #Save the user's input to a temp variable
  bet_amount = params['bet_amount'].to_i

  #Check for an out of range number
  if bet_amount > session['balance']
    session['error'] = "Bet cannot be greater than what you have ($#{session['balance']})."
    redirect '/bet'
  end

  #Save the input and advance gameplay
  session['bet_amount'] = bet_amount
  session['status'] = 'dealing_to_player'
  session['error'] = nil #reset the error message buffer
  redirect '/game'

end

#Game actions

#Dealer hit action
#Client issues this request using Ajax
post '/game/player/hit' do
  deal_card('player_cards')
  decide_status
  erb :game, layout: false
end

#Player stay action
#Client issues this request using Ajax
post '/game/player/stay' do

  session['player_stayed'] = true
  session['status']  = 'dealing_to_dealer'
  append_message("#{session['name']} stays at #{hand_total('player_cards')}. ")
  decide_status
  erb :game, layout: false

  end

#Dealer hit action
#Client issues this request using Ajax
post '/game/dealer/hit' do
  deal_card('dealer_cards')
  decide_status
  erb :game, layout: false
end

#Direct player to appropriate goodbye screen
get '/goodbye' do

  @balance = session['balance']

  if @balance > 0
    erb :winner_bye
  else
    erb :loser_bye   
  end

end

#Display the main game screen
get '/game' do

  #Custom messages containing user's name
  STATUS_MESSAGES = {'player_won' => "#{session['name']} won. ", 'dealer_won' => 'Dealer won. ',
                  'push' => "Push. "}

   decide_status #decide what the state of the game is
 
   read_session #read the contents of the session cookie

  #Sanity checks

  #No cards dealt?

  if session['dealer_cards'].empty?
    raise "No cards dealt to dealer"
  end

  if session['player_cards'].empty?
    raise "No cards dealt to player"
  end

  #Bet amount is not a valid number
  if (!session['bet_amount'].is_a?(Fixnum)  ||
    session['bet_amount'] <= 0)
    raise "Illegal bet"
  end

  #Convert cards to image files
  @dealer_images=show_hand('dealer_cards')
  @player_images=show_hand('player_cards')

  erb :game

 end

get '/start_over' do
  session.clear
  redirect 'get_name'
end

