export interface User {
  userId: number;
  loginId: string;
  firstName: string;
  lastName: string;
  roleId: number;
  clientId: number;
}

export interface LoginResponse {
  token: string;
  user: User;
}
