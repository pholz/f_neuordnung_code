#include <Neuroduino.h>

#define NUM_LAYERS 2
#define ETA 0.2
#define THETA 0.0
#define DEBUG true

extern int __bss_end;
extern void *__brkval;

double netArray[NUM_LAYERS] = {7,1};
double inputArray[] = {1, -1, 1, -1, -1, 1, -1};
double trainArray[] = {0};
int weightArray[7];
int potArray[] = {512, 512, 512, 512, 512, 512, 512, 512};

int netMem = get_free_memory();

// Neuroduino params: (network array, number of layers, Eta, Theta, debug)
Neuroduino myNet(netArray, NUM_LAYERS, ETA, THETA, DEBUG);

// free memory check
// from: http://forum.pololu.com/viewtopic.php?f=10&t=989#p4218
int get_free_memory(){
  int free_memory;
  if((int)__brkval == 0)
    free_memory = ((int)&free_memory) - ((int)&__bss_end);
  else
    free_memory = ((int)&free_memory) - ((int)__brkval);

  return free_memory;
}

int checkMem(){
  Serial.print("Free memory: ");
  Serial.println(get_free_memory(), DEC);
}

void printArray(double arr[], int len){
  int i;
  Serial.print("[");
  for(i=0; i<len; i++){
    Serial.print(arr[i], DEC);
    if(i != len-1) Serial.print(", ");
  }
  Serial.println("]");
}

//Pin connected to ST_CP of 74HC595
int latchPin = 8;
//Pin connected to SH_CP of 74HC595
int clockPin = 12;
////Pin connected to DS of 74HC595
int dataPin = 11;
boolean firstContact = false;

//holders for infromation you're going to pass to shifting function

byte m0_up = B00000001;
byte m0_dn = B00000010;
byte off = B00000000;
byte m1_up = B00000100;
byte m1_dn = B00001000;
byte m2_up = B00010000;
byte m2_dn = B00100000;
byte m3_up = B01000000;
byte m3_dn = B10000000;
byte m0[2] = {m0_up, m0_dn};
byte m1[2] = {m1_up, m1_dn};
byte m2[2] = {m2_up, m2_dn};
byte m3[2] = {m3_up, m3_dn};

byte state[8] = {0, 1, 1, 1, 1, 1, 1, 1};

void setup() {
  //set pins to output because they are addressed in the main loop
  pinMode(latchPin, OUTPUT);
  Serial.begin(9600);
  
  // establishContact();
  netMem -= get_free_memory();
  myNet.randomizeWeights();
}

void establishContact() {
  while (Serial.available() <= 0) {
    Serial.print('A', BYTE);   // send a capital A   // send an initial string
    delay(300);
  }
  firstContact = true;
}

void loop() {
    
 //   delay(60);
    
  /*
    if(Serial.available() > 0) { 
      for(int i = 0; i < 8; i++){
        state[i] = Serial.read();
      }
    }
   */ 
    
  for(int i = 0; i < 7; i++)
  {
    inputArray[i] = (double)(rand() % 100 -50);
  }
  
  double sumEven = inputArray[0] + inputArray[2] + inputArray[4] + inputArray[6];
  double clas = sumEven < 0 ? -1 : 1;
  trainArray[0] = clas;

  myNet.train(inputArray, trainArray);
  myNet.printNet();
  printArray(myNet.simulate(inputArray), netArray[1]);
  
  for(int i = 0; i < 7; i++)
  {
   weightArray[i] = map((int) (myNet.getWeight(1,0,i) * 100), -5000, 5000, 0, 1024 );
   if       (weightArray[i] < potArray[i] - 1) state[i] = 2;
   else if  (weightArray[i] > potArray[i] + 1) state[i] = 1;
   else                                        state[i] = 0;
  }

    //load the light sequence you want from array
    //ground latchPin and hold low for as long as you are transmitting
    digitalWrite(latchPin, 0);
    //move 'em out
    // RIGHT H-BRIDGES
   
    shiftOut(dataPin, clockPin, (state[0] > 0 ? m0[state[0]-1] : off) | 
                                (state[1] > 0 ? m1[state[1]-1] : off) | 
                                (state[2] > 0 ? m2[state[2]-1] : off) |
                                (state[3] > 0 ? m3[state[3]-1] : off) );   
    // LEFT H-BRIDGES
    shiftOut(dataPin, clockPin, (state[4] > 0 ? m0[state[4]-1] : off) | 
                                (state[5] > 0 ? m1[state[5]-1] : off) | 
                                (state[6] > 0 ? m2[state[6]-1] : off) |
                                (state[7] > 0 ? m3[state[7]-1] : off) ); 
   

    digitalWrite(latchPin, 1);
    delay(1000);


}



// the heart of the program
void shiftOut(int myDataPin, int myClockPin, byte myDataOut) {
  // This shifts 8 bits out MSB first, 
  //on the rising edge of the clock,
  //clock idles low

  //internal function setup
  int i=0;
  int pinState;
  pinMode(myClockPin, OUTPUT);
  pinMode(myDataPin, OUTPUT);

  //clear everything out just in case to
  //prepare shift register for bit shifting
  digitalWrite(myDataPin, 0);
  digitalWrite(myClockPin, 0);

  //for each bit in the byte myDataOut�
  //NOTICE THAT WE ARE COUNTING DOWN in our for loop
  //This means that %00000001 or "1" will go through such
  //that it will be pin Q0 that lights. 
  for (i=7; i>=0; i--)  {
    digitalWrite(myClockPin, 0);

    //if the value passed to myDataOut and a bitmask result 
    // true then... so if we are at i=6 and our value is
    // %11010100 it would the code compares it to %01000000 
    // and proceeds to set pinState to 1.
    if ( myDataOut & (1<<i) ) {
      pinState= 1;
    }
    else {	
      pinState= 0;
    }

    //Sets the pin to HIGH or LOW depending on pinState
    digitalWrite(myDataPin, pinState);
    //register shifts bits on upstroke of clock pin  
    digitalWrite(myClockPin, 1);
    //zero the data pin after shift to prevent bleed through
    digitalWrite(myDataPin, 0);

  }

  //stop shifting
  digitalWrite(myClockPin, 0);
}



