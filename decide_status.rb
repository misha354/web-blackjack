module Sinatra
	module DecideStatus  
	  #A method to decide the status of the game after an action.
	  #Sets the message accordingly.
	  #This method contains all the game logic.
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
	        elsif hand_total('player_cards') == MyApp::WIN_VALUE
	          append_message("Player stays at #{MyApp::WIN_VALUE}. ")
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
	        elsif hand_total('dealer_cards') >= MyApp::STAY_VALUE
	            
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
	end
end