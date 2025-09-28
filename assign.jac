import from byllm.llm { Model }

glob llm = Model(model_name='gemini/gemini-2.0-flash', verbose=True);

def generate_password(length: int) -> str by llm();

"""
Generate a random password of exactly {length} characters.
It must include uppercase, lowercase, digits, and symbols.
Only output the password itself, nothing else.
"""

walker PasswordGenerator {
    has length: int;

    can start with `root entry;
    can generate with turn entry;
    
    
}

node turn {
    has length: int;

    can generate with PasswordGenerator entry{
        print("Generating password with length:", self.length);
        password = generate_password(self.length);
        print("Generated password:", password);
        print(password);
    }    
}

impl PasswordGenerator.start{
    next = turn(length=self.length); 
    root ++> next;
    visit next;
    next.generate(self);
}

impl PasswordGenerator.generate{
}



with entry:__main__ {
    root  spawn  PasswordGenerator (length=12);
} 

