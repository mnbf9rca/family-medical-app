// backend/src/opaque.ts
// OPAQUE authentication handlers using @serenity-kit/opaque

import * as opaque from '@serenity-kit/opaque';

// Server setup (initialized from environment secret)
let serverSetup: string | null = null;

export function initServerSetup(storedSetup: string | null): void {
  if (storedSetup) {
    serverSetup = storedSetup;
  } else {
    // Generate new setup if none exists (should only happen once, then store as secret)
    serverSetup = opaque.server.createSetup();
    console.warn('[opaque] Generated new server setup - this should be stored as a secret!');
  }
}

export function getServerSetup(): string {
  if (!serverSetup) {
    throw new Error('OPAQUE server setup not initialized');
  }
  return serverSetup;
}

// Registration flow
export interface RegistrationStartResult {
  registrationResponse: string;
}

export function startRegistration(
  clientIdentifier: string,
  registrationRequest: string
): RegistrationStartResult {
  const { registrationResponse } = opaque.server.createRegistrationResponse({
    serverSetup: getServerSetup(),
    userIdentifier: clientIdentifier,
    registrationRequest,
  });

  return { registrationResponse };
}

export interface RegistrationFinishResult {
  passwordFile: string;
}

export function finishRegistration(
  registrationRecord: string
): RegistrationFinishResult {
  // In OPAQUE, the client sends a "registration record" which becomes the password file
  // The @serenity-kit/opaque library uses "registrationRecord" terminology
  return { passwordFile: registrationRecord };
}

// Login flow
export interface LoginStartResult {
  credentialResponse: string;
  serverState: string;
}

export function startLogin(
  clientIdentifier: string,
  passwordFile: string,
  credentialRequest: string
): LoginStartResult {
  const { serverLoginState, loginResponse } = opaque.server.startLogin({
    serverSetup: getServerSetup(),
    userIdentifier: clientIdentifier,
    registrationRecord: passwordFile,
    startLoginRequest: credentialRequest,
  });

  return {
    credentialResponse: loginResponse,
    serverState: serverLoginState,
  };
}

export interface LoginFinishResult {
  sessionKey: string;
}

export function finishLogin(
  serverState: string,
  credentialFinalization: string
): LoginFinishResult {
  const { sessionKey } = opaque.server.finishLogin({
    finishLoginRequest: credentialFinalization,
    serverLoginState: serverState,
  });

  return { sessionKey };
}
