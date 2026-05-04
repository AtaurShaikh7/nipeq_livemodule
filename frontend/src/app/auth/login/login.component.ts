import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from '../auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatProgressSpinnerModule,
    MatIconModule,
  ],
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.scss'],
})
export class LoginComponent {
  form = this.fb.group({
    loginId:  ['', Validators.required],
    password: ['', Validators.required],
  });

  loading = false;
  error   = '';
  hidePassword = true;

  constructor(private fb: FormBuilder, private auth: AuthService, private router: Router) {}

  onSubmit(): void {
    if (this.form.invalid) return;
    this.loading = true;
    this.error   = '';

    const { loginId, password } = this.form.value;
    this.auth.login(loginId!, password!).subscribe({
      next: () => this.router.navigate(['/portfolio']),
      error: (err) => {
        this.loading = false;
        this.error = err?.error?.error || 'Login failed. Please check your credentials.';
      },
    });
  }
}
