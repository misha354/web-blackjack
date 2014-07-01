#A web-based blackjack game written in Sinatra
#Author:: Mike Zhukovskiy

require 'rubygems'
require_relative 'name_handler'
require_relative 'session_helpers'
require_relative 'decide_status'
require 'sinatra'

#@author Mike Zhukovskiy
class MyApp < Sinatra::Base 

  set :sessions, true 
  disable :show_exceptions
  disable :raise_errors 

  register  Sinatra::NameHandler #a module that deals with player name I/O

  register Sinatra::SessionHelpers #a module of methods that modify the session hash
  helpers Sinatra::SessionHelpers

  #The main game logic module
  register Sinatra::DecideStatus
  helpers Sinatra::DecideStatus 

  #Constants

  #number of decks in the game
  NDECKS = 1  

  #The amount of money that the player starts with
  START_AMT =500  

  WIN_VALUE = 21 #The object is to get a hand worth this many points  

  STAY_VALUE = 17 #Dealer stays at this value 

  SUITS = ["hearts","spades","diamonds","clubs"]  

  RANKS = ["2", "3", "4", "5", "6", "7", "8", 
          "9", "10", "jack", "queen", "king", "ace"]  

  #directory containing card images
  IMAGE_DIR = "/images/cards" 

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

  # Contains a helper method to access card images 
  module ShowHand 

    # Returns paths of image files corresponding to the cards in a specified hand.
    # The hand is stored as an array in the session hash 
    # @method show_hand
    # @param hand [String] tells the method which hand to access,
    #    valid values 'player_cards' or 'dealer_cards'
    def show_hand(hand) 

      #Iterate over the cards, converting each to a file path
      images = session[hand].map do |card|
        "#{IMAGE_DIR}/#{card['suit']}_#{card['rank']}.jpg"     
      end 

      #Hide the player's first card if it's the dealers turn
      if(session['status'] == 'dealing_to_player' && hand=='dealer_cards')
        images[0] = "#{IMAGE_DIR}/cover.jpg"
      end 

      return images 

    end
  end
  helpers ShowHand #make the module accessible to routes and views  

  #Contains a helper method that creates a fresh game in the session hash
  module CreateGame 

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
  end
  helpers CreateGame #make accessible to routes/views 

  #Contains methods that move around cards
  module MoveCards  

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
    #@param hand [String] tells the method which hand to access,
    #    valid values 'player_cards' or 'dealer_cards'
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
  end
  helpers MoveCards 

  #Contains methods that count cards
  module CountCards 

    #A method that checks if the specified hand is a blackjack
    #@param hand [String] tells the method which hand to access,
    #    valid values 'player_cards' or 'dealer_cards'
    def blackjack?(hand)
   
      return hand_total( hand ) == WIN_VALUE && session[hand].length == 2
      
    end 

    #a method that checks if the specify hand busted
     #@param hand [String] tells the method which hand to access,
    #    valid values 'player_cards' or 'dealer_cards'
    def bust?(hand)
      return hand_total( hand ) > WIN_VALUE 

    end 

     #Totals the points for a hand
    #@param hand [String] tells the method which hand to access,
    #    valid values 'player_cards' or 'dealer_cards'
    def hand_total(hand)  

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
  end
  helpers CountCards  

  #@method get_bet
  #@overload get '/bet' 
  #Sinatra route that requests a bet amount.
  #Request is submitted using {#post_bet post '/bet'}
  get '/bet' do
  #Uses session['error'] and @error to display error messages 

    @name = session['name']
    @message = session['message']
    @balance = session['balance']
    @error = session['error'] 
    session['bet_amount'] = nil
    erb :bet  

   end 

  # @method getslash
  # @overload get '/'
  # The root route. If no name saved, redirects to {Sinatra::NameHandler#get_get_name get '/name'}.
  # If no bet saved, redirects to {#get_bet get '/bet'}.
  # Otherwise, redirects to {#get_game get '/game'}

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

  # @method get_new_game
  # @overload get '/new_game'
  # Initializes a new game.
  # Redirects to {#get_new_hand get '/new_hand'}
  get '/new_game' do
    create_game
    clear_message
    clear_status
    redirect '/new_hand'
  end 

  #@method get_new_hand
  #@overload get '/new_hand'
  # Deals a new hand.
  #Redirects to {#get_goodbye} if player ran out of money, or to {#get_bet get '/bet'}
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

  #@method post_bet
  #@overload post '/bet'
  # Read the user's bet
  # and redirect to {#get_game get '/game'}
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

  #@ method post_game_player_hit
  #overload post '/game/player/hit'
  #Dealer hit action.
  #Client issues this request using Ajax
  post '/game/player/hit' do
    deal_card('player_cards')
    decide_status
    erb :game, layout: false
  end 

  #@method post_game_player_stay
  #@overload post '/game/player/stay'  
  # Player stay action.
  #  Client issues this request using Ajax.
  post '/game/player/stay' do 

    session['player_stayed'] = true
    session['status']  = 'dealing_to_dealer'
    append_message("#{session['name']} stays at #{hand_total('player_cards')}. ")
    decide_status
    erb :game, layout: false  

    end 

  #@method post_game_dealer_hit
  #@overload post '/game/dealer/hit'
  #Dealer hit action.
  #Client issues this request using Ajax.
  post '/game/dealer/hit' do
    deal_card('dealer_cards')
    decide_status
    erb :game, layout: false
  end 

  #@method get_goodbye
  #@overload get '/goodbye'
  #Direct player to appropriate goodbye screen
  get '/goodbye' do 

    @balance = session['balance'] 

    if @balance > 0
      erb :winner_bye
    else
      erb :loser_bye   
    end 

  end 

  #@method get_game
  #@overload get '/game'
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

    # start the server if ruby file executed directly
    run! if app_file == $0

end



