import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of, tap } from 'rxjs';
import { Router } from '@angular/router';
import { LoginResponse, User } from '../shared/models/user.model';
import { environment } from '../../environments/environment';
import { USE_MOCK } from '../portfolio/portfolio.service';

const TOKEN_KEY = 'nipeq_token';
const USER_KEY  = 'nipeq_user';

// A valid-looking JWT that won't expire until 2099 (mock only)
const MOCK_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJsb2dpbl9pZCI6InN1cHBvcnRAdmFsdWVmeS5jb20iLCJleHAiOjQwODk0NjQ0MDB9.mock_signature';
const MOCK_USER  = { user_id: 1, login_id: 'support@valuefy.com', full_name: 'Support User' };

@Injectable({ providedIn: 'root' })
export class AuthService {
  constructor(private http: HttpClient, private router: Router) {}

  login(loginId: string, password: string): Observable<LoginResponse> {
    if (USE_MOCK) {
      const res: LoginResponse = { token: MOCK_TOKEN, user: MOCK_USER as unknown as User };
      localStorage.setItem(TOKEN_KEY, res.token);
      localStorage.setItem(USER_KEY, JSON.stringify(res.user));
      return of(res);
    }
    return this.http.post<LoginResponse>(`${environment.apiUrl}/auth/login`, { loginId, password }).pipe(
      tap(res => {
        localStorage.setItem(TOKEN_KEY, res.token);
        localStorage.setItem(USER_KEY, JSON.stringify(res.user));
      })
    );
  }

  logout(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    this.router.navigate(['/login']);
  }

  getToken(): string | null {
    return localStorage.getItem(TOKEN_KEY);
  }

  getUser(): User | null {
    const raw = localStorage.getItem(USER_KEY);
    return raw ? JSON.parse(raw) : null;
  }

  isLoggedIn(): boolean {
    const token = this.getToken();
    if (!token) return false;
    if (USE_MOCK) return true;
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.exp * 1000 > Date.now();
    } catch {
      return false;
    }
  }
}
