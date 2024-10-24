So, aveti in arhiva scriptul si modelul.
In script trebuie sa modificati:
	- calea catre model (linia 79)
	- calea catre folderul unde va fi fisierul audio (linia 84)
	- calea la care sa scrie fisierul cu rezultatul (liniile 101 si 106)

Fisierul audio va trebui
	- sa aiba o denumire care sa inceapa cu un numar urmat de underscore
	- sa aiba extensia .wav
	- ex. 12_inregistrare.wav (unde 12 e ID-ul pacientului, any number will do)

Scriptul se ruleaza:
	- pe un PC cu python instalat
	- ca si linie de comanda main.py -12 (daca 12 e id-ul pacientului conform exemplului de mai sus)
	- scrie atat in fisier cat si in consola un text de genul "Dr. Ai Bot is 72% sure that the patient is sick"