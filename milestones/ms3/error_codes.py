
# Error code mapping
code_to_msg = {
    0: "Operation completed successfully.",
    -1: "Invalid input provided. Please check the values you entered.",
    -2: "This record or value already exists. Please choose another one.",
    -3: "You are not authorized to perform this action.",
    -4: "This action cannot be performed due to the current status of the record.",
    -5: "This business does not deliver to your active address zone.",
    -6: "The requested quantity exceeds the allowed limit (maximum 10).",
    -7: "Payment could not be processed. Check your balance or choose another payment method.",
    -8: "No riders are currently available in this zone. Please try again shortly.",
    -9: "Nothing to process. Please add items before proceeding."
}

def get_message(code: int, custom_messages: dict = None) -> str:
    
    if custom_messages and code in custom_messages and isinstance(custom_messages[code], str):
            return custom_messages[code]
        
    return code_to_msg.get(code, "An unexpected error occurred. Please try again.")

