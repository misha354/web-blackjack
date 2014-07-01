module Sinatra
  #Methods that access and update the contents of the session cookie
  module SessionHelpers
    
    #Reads the contents of the session cookie and saves it to instance variables
    def read_session  

      @message = session['message'] #set the message instance variable  

      #Validate status
      if !MyApp::VALID_STATUSES.include?(session['status'])
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
  

    #Clears the message buffer
    def clear_message
      session['message'] = nil
      session['message_class'] = 'alert'
    end 

    #Clears the status
    def clear_status
      session['status'] = nil
    end 

    #Appends the passed string string to the message buffer
    # @param message [String] the string to append 
    def append_message(message)
      session['message'] = session['message'].to_s + message
    end 

    #Handles the dealer win
    def record_dealer_win
      session['message_class'] = 'error'
      session['status'] = 'dealer_won'
      session['balance'] -= session['bet_amount']
    end 

    #Handles the player win
    def record_player_win
      session['message_class'] = 'success'
      session['status'] = 'player_won'
      session['balance'] += session['bet_amount']
    end
  end
end