enum PasswordMismatchRecoverySituation {
  none,
  remoteUserDiffers,
  remoteFileDiffers,

  //TODO:f: Probably can never know that these are the situation - can't tell the difference
  // between user typing the wrong password and can't try the remote file password anyway
  // until the service password is correct. Maybe delete these enum values?
  //RemoteUserAndFileDiffers,
  //AllThreeAreDifferent
}

/*

We try to automatically resolve all mismatched password situations here.

There are 3 current passwords we need to align - they generally always are aligned but crashes or bugs, particularly during a password change procedure, can cause them to get out of sync.

The 3 passwords are:
Local KDBX file - the remoteMargeTarget unless current is newer
Remote KDBX file
Remote user authentication password

We'll need to align on the remote authentication password so that the user doesn't get stuck in a constant battle between conflicting local passwords on multiple devices.

Slightly old tokens being used to upload modified RK could result in state 1 or 2.

p1 p2 and p3 have no specific temporal ordering. Depending on how we ended up in one of these states, any of those could be considered "newest".

Thus the possible failure modes are:

1) RemoteUserDiffers

LK = p1
RK = p1
RU = p2

Symptom:
User will be unable to download or upload the RK file

Solution: 
User provides an override password which we use for authentication.
Need to use non-override password to unlock RK. But we don't know in advance if we are in this state or 3. So we assume 3 and actually progress towards state 2. Ideally we resolve in the same step by just trying again with p1 but in worst case user could enter a password again.
If RK is newer, download it, change its password to p2, change LK password to p2, merge it, store result as LK and upload as RK.
If RK is not newer, change LK password to p2, store result as LK and upload as RK.


2) RemoteFileDiffers

LK = p1
RK = p2
RU = p1

Symptom:
User will be unable to unlock the RK file while merging for upload or downloading for refresh/syncing.

Solution: 
User provides an override password which we use for unlocking the RK.
Need to use non-override password to download/upload RK. So we need to know that RU worked when getting p2 from the user.
If RK is newer, download it, change its password to p1, merge it, store result as LK and upload as RK.
If RK is not newer, upload LK as RK.


3) RemoteUserAndFileDiffers

LK = p1
RK = p2
RU = p2

Symptom:
User will be unable to download or modify the RK file, nor unlock it using their local password

Solution: 
User provides an override password which we use for authentication and to unlock RK.
If RK is newer, download it, change LK password to p2, merge it, store result as LK and upload as RK.
If RK is not newer, change LK password to p2, store result as LK and upload as RK.

4) AllThreeAreDifferent

LK = p1
RK = p2
RU = p3

Solution: 
Ignore. We hope that existing support for other situations will allow the user to muddle through to a resolution in multiple steps.



Generally, we will need to track whether it was the RK or RU that failed. That lets us determine between states 1,2 and 3+4. We know we are in 3+4 if trying to resolve 3 fails at either the access request or RK unlocking stage. Once the user enters p3, we can change LK with that password and thus effectively reduce the problem to state 1 (which user can then resolve by entering what was p2 in this scenario). We won't implement all of this edge case but expect at least that forcibly killing the app at the right time will allow the user to recover.
*/